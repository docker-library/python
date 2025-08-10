discord.py>=2.4.0
python-dotenv>=1.0.0
openai>=1.35.0
aiosqlite>=0.19.0
psycopg2-binary>=2.9.9
drizzle-orm>=0.24.0
#!/usr/bin/env python3
"""
Seraphina - Discord bot
- dependency check
- logging to file+console
- sqlite (aiosqlite) messages table
- global tribute detection -> DM owner + DB log (rate-limited)
- auto-reply when bot mentioned or custom trigger
- !chat command
- safe OpenAI calls in executor
"""

import sys
import os
import asyncio
import logging
import traceback
import re
from datetime import datetime, timedelta
from typing import Optional

# --------- Dependency check ---------
required_packages = ["discord", "dotenv", "openai", "aiosqlite"]
_missing = []
for pkg in required_packages:
    try:
        __import__(pkg)
    except ImportError:
        _missing.append(pkg)

if _missing:
    print("\n[ERROR] Missing required packages:")
    for p in _missing:
        print(f" - {p}")
    print("\nInstall them with:")
    print("pip3 install " + " ".join(_missing))
    sys.exit(1)

# --------- Imports (after check) ---------
import discord
from discord.ext import commands
from dotenv import load_dotenv
import openai
import aiosqlite

# --------- Logging ---------
LOGFILE = "seraphina.log"
logging.basicConfig(
    filename=LOGFILE,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s", "%Y-%m-%d %H:%M:%S")
console.setFormatter(formatter)
logging.getLogger("").addHandler(console)

logging.info("Starting Seraphina bot...")

# --------- Load env ---------
load_dotenv()
DISCORD_TOKEN = os.getenv("DISCORD_TOKEN")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OWNER_ID = int(os.getenv("OWNER_ID", "0") or 0)

if not DISCORD_TOKEN:
    logging.error("DISCORD_TOKEN missing in .env")
    sys.exit(1)
if not OPENAI_API_KEY:
    logging.error("OPENAI_API_KEY missing in .env")
    sys.exit(1)
if not OWNER_ID:
    logging.warning("OWNER_ID missing or zero in .env. Tribute DMs will fail until set.")

openai.api_key = OPENAI_API_KEY

# --------- Database ---------
DB_PATH = "seraphina.db"

async def init_db():
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("""
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                message_id TEXT,
                channel_id TEXT,
                guild_id TEXT,
                user_id TEXT,
                username TEXT,
                content TEXT,
                is_tribute INTEGER DEFAULT 0,
                processed_by_bot INTEGER DEFAULT 0,
                bot_response TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)
        await db.execute("CREATE INDEX IF NOT EXISTS idx_messages_user ON messages(user_id)")
        await db.commit()
    logging.info("Database initialized.")

# --------- Bot & intents ---------
intents = discord.Intents.default()
intents.message_content = True
intents.messages = True
intents.guilds = True
intents.members = True

bot = commands.Bot(command_prefix="!", intents=intents, reconnect=True)

# --------- Tribute detection config ---------
TRIBUTE_KEYWORDS = [
    r"\btribute\b",
    r"\bdonate\b",
    r"\bsend money\b",
    r"\bcashapp\b",
    r"\bvenmo\b",
    r"\bpay\b",
    r"\bpayment\b",
    r"\bpaypal\b",
    r"\btransfer\b"
]
TRIBUTE_RE = re.compile("|".join(TRIBUTE_KEYWORDS), flags=re.IGNORECASE)

# simple per-user cooldown to avoid DM spam (user_id -> last_notification_time)
tribute_cooldown_seconds = 60 * 5  # 5 minutes per user
_last_tribute_notify = {}  # user_id -> datetime

# --------- Utilities ---------
def is_tribute_text(text: str) -> bool:
    if not text:
        return False
    return bool(TRIBUTE_RE.search(text))

async def notify_owner_dm(owner_id: int, content: str) -> bool:
    owner = bot.get_user(owner_id)
    if owner is None:
        try:
            owner = await bot.fetch_user(owner_id)
        except Exception as e:
            logging.error("Failed to fetch owner user: %s", e)
            return False
    try:
        await owner.send(content)
        return True
    except Exception as e:
        logging.error("Failed to DM owner: %s", e)
        return False

async def call_openai_async(user_message: str, system_prompt: Optional[str] = None, max_tokens: int = 300) -> str:
    loop = asyncio.get_running_loop()
    def blocking_call():
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": user_message})
        resp = openai.ChatCompletion.create(
            model="gpt-4o-mini",
            messages=messages,
            max_tokens=max_tokens,
            temperature=0.7,
        )
        return resp
    try:
        resp = await loop.run_in_executor(None, blocking_call)
        # Extract content safely
        if isinstance(resp, dict):
            choices = resp.get("choices", [])
        else:
            choices = getattr(resp, "choices", [])
        if choices:
            # support various shapes
            choice0 = choices[0]
            if isinstance(choice0, dict):
                msg = choice0.get("message", {}) or {}
                return msg.get("content", "") or choice0.get("text", "") or ""
            else:
                # object-like
                msg = getattr(choice0, "message", None)
                if msg:
                    return msg.get("content", "") if isinstance(msg, dict) else getattr(msg, "get", lambda k, d=None: "")("content", "")
                return getattr(choice0, "text", "") or ""
        return ""
    except Exception as e:
        logging.error("OpenAI call failed: %s", e)
        return f"[OpenAI error: {e}]"

# --------- Events & message processing ---------
@bot.event
async def on_ready():
    logging.info(f"Logged in as {bot.user} (id: {bot.user.id})")
    await init_db()

@bot.event
async def on_error(event_method, *args, **kwargs):
    logging.error("on_error triggered for %s", event_method)
    logging.error(traceback.format_exc())

@bot.event
async def on_message(message: discord.Message):
    # Ignore bots
    if message.author.bot:
        return

    # Tribute detection + DB log
    try:
        content = message.content or ""
        is_tribute = is_tribute_text(content)

        # Save raw message
        try:
            async with aiosqlite.connect(DB_PATH) as db:
                await db.execute(
                    "INSERT INTO messages (message_id, channel_id, guild_id, user_id, username, content, is_tribute, processed_by_bot) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    (
                        str(message.id),
                        str(message.channel.id),
                        str(message.guild.id) if message.guild else None,
                        str(message.author.id),
                        str(message.author),
                        content,
                        1 if is_tribute else 0,
                        0
                    )
                )
                await db.commit()
        except Exception as e:
            logging.error("Failed to log message to DB: %s", e)

        if is_tribute:
            now = datetime.utcnow()
            last = _last_tribute_notify.get(message.author.id)
            if last is None or (now - last).total_seconds() >= tribute_cooldown_seconds:
                _last_tribute_notify[message.author.id] = now
                dm_text = (
                    f"💰 **Tribute Offer Detected**\n"
                    f"From: {message.author} (ID: {message.author.id})\n"
                    f"Channel: {message.channel} (ID: {message.channel.id})\n"
                    f"Guild: {message.guild.name if message.guild else 'DM'}\n"
                    f"Time (UTC): {now.isoformat()}Z\n\n"
                    f"Message:\n{content}"
                )
                success = await notify_owner_dm(OWNER_ID, dm_text)
                if success:
                    logging.info("Owner notified about tribute from %s", message.author)
                else:
                    logging.warning("Could not notify owner.")
            else:
                logging.info("Tribute detected but on cooldown for user %s", message.author)

    except Exception as e:
        logging.error("Error during tribute detection: %s", e)

    # Auto-reply rules
    try:
        should_respond = False
        user_query = None

        if bot.user in message.mentions:
            should_respond = True
            user_query = re.sub(rf"<@!{bot.user.id}>|<@{bot.user.id}>", "", content).strip()

        if not should_respond and content.lower().strip().startswith("seraphina,"):
            should_respond = True
            user_query = content.split(",", 1)[1].strip() if "," in content else content

        if should_respond and user_query:
            await message.channel.trigger_typing()
            system_prompt = "You are Mistress Seraphina, confident and polite. Keep replies concise, authoritative, and seductive when appropriate."
            bot_reply = await call_openai_async(user_query, system_prompt=system_prompt, max_tokens=220)

            # update DB
            try:
                async with aiosqlite.connect(DB_PATH) as db:
                    await db.execute(
                        "UPDATE messages SET bot_response = ?, processed_by_bot = 1 WHERE message_id = ?",
                        (bot_reply, str(message.id))
                    )
                    await db.commit()
            except Exception as e:
                logging.error("Failed to update DB with bot response: %s", e)

            try:
                await message.channel.send(bot_reply, allowed_mentions=discord.AllowedMentions(users=True, roles=False, everyone=False))
            except Exception as e:
                logging.error("Failed to send public reply: %s", e)

    except Exception as e:
        logging.error("Error handling auto-reply: %s", e)

    await bot.process_commands(message)

# --------- !chat command ---------
@bot.command(name="chat")
async def _chat_cmd(ctx: commands.Context, *, prompt: str):
    await ctx.trigger_typing()
    system_prompt = "You are Mistress Seraphina, an intelligent, confident personality. Keep replies concise and authoritative."
    bot_reply = await call_openai_async(prompt, system_prompt=system_prompt, max_tokens=300)

    try:
        async with aiosqlite.connect(DB_PATH) as db:
            await db.execute(
                "INSERT INTO messages (message_id, channel_id, guild_id, user_id, username, content, is_tribute, processed_by_bot, bot_response) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (None, str(ctx.channel.id), str(ctx.guild.id) if ctx.guild else None, str(ctx.author.id), str(ctx.author), prompt, 1 if is_tribute_text(prompt) else 0, 1, bot_reply)
            )
            await db.commit()
    except Exception as e:
        logging.error("Failed to log chat command usage: %s", e)

    await ctx.send(bot_reply, allowed_mentions=discord.AllowedMentions(users=True, roles=False, everyone=False))

# --------- Runner with restart loop ---------
async def run_bot():
    while True:
        try:
            await bot.start(DISCORD_TOKEN)
        except Exception as e:
            logging.error("Bot crashed: %s", e)
            logging.error(traceback.format_exc())
            logging.info("Restarting in 5 seconds...")
            await asyncio.sleep(5)

if __name__ == "__main__":
    try:
        asyncio.run(run_bot())
    except KeyboardInterrupt:
        logging.info("Bot stopped manually.")