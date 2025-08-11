{{
	def is_alpine:
		env.variant | startswith("alpine")
	;
	def is_slim:
		env.variant | startswith("slim-")
	;
	def rcVersion:
		env.version | rtrimstr("-rc")
	;
	def clean_apt:
		# TODO once bookworm is EOL, remove this and just hard-code "apt-get dist-clean" instead
		if env.variant | contains("bookworm") then
			"rm -rf /var/lib/apt/lists/*"
		else "apt-get dist-clean" end
-}}
{{ if is_alpine then ( -}}
FROM alpine:{{ env.variant | ltrimstr("alpine") }}
{{ ) elif is_slim then ( -}}
FROM debian:{{ env.variant | ltrimstr("slim-") }}-slim
{{ ) else ( -}}
FROM buildpack-deps:{{ env.variant }}
{{ ) end -}}

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

{{ if rcVersion | IN("3.9", "3.10", "3.11", "3.12") then ( -}}
{{ # only set LANG on versions less than 3.13 -}}
# cannot remove LANG even though https://bugs.python.org/issue19846 is fixed
# last attempted removal of LANG broke many users:
# https://github.com/docker-library/python/pull/570
ENV LANG C.UTF-8

{{ ) else "" end -}}
# runtime dependencies
{{ if is_alpine then ( -}}
RUN set -eux; \
	apk add --no-cache \
		ca-certificates \
		tzdata \
	;
{{ ) else ( -}}
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
{{ if is_slim then ( -}}
		ca-certificates \
		netbase \
		tzdata \
{{ ) else ( -}}
		libbluetooth-dev \
		tk-dev \
		uuid-dev \
{{ ) end -}}
	; \
	{{ clean_apt }}
{{ ) end -}}

{{
	def should_pgp:
		# https://github.com/docker-library/python/issues/977
		# https://peps.python.org/pep-0761/
		# https://discuss.python.org/t/pep-761-deprecating-pgp-signatures-for-cpython-artifacts/67180
		rcVersion | IN("3.9", "3.10", "3.11", "3.12", "3.13")
-}}
{{ if should_pgp then ( -}}
ENV GPG_KEY {{
	{
		# gpg: key B26995E310250568: public key "\xc5\x81ukasz Langa (GPG langa.pl) <lukasz@langa.pl>" imported
		"3.9": "E3FF2839C048B25C084DEBE9B26995E310250568",
		# https://peps.python.org/pep-0596/#release-manager-and-crew

		# gpg: key 64E628F8D684696D: public key "Pablo Galindo Salgado <pablogsal@gmail.com>" imported
		"3.10": "A035C8C19219BA821ECEA86B64E628F8D684696D",
		# https://peps.python.org/pep-0619/#release-manager-and-crew

		# gpg: key 64E628F8D684696D: public key "Pablo Galindo Salgado <pablogsal@gmail.com>" imported
		"3.11": "A035C8C19219BA821ECEA86B64E628F8D684696D",
		# https://peps.python.org/pep-0664/#release-manager-and-crew

		# gpg: key A821E680E5FA6305: public key "Thomas Wouters <thomas@python.org>" imported
		"3.12": "7169605F62C751356D054A26A821E680E5FA6305",
		# https://peps.python.org/pep-0693/#release-manager-and-crew

		# gpg: key A821E680E5FA6305: public key "Thomas Wouters <thomas@python.org>" imported
		"3.13": "7169605F62C751356D054A26A821E680E5FA6305",
		# https://peps.python.org/pep-0719/#release-manager-and-crew
	}[rcVersion]
}}
{{ ) else "" end -}}
ENV PYTHON_VERSION {{ .version }}
{{ if .checksums.source.sha256 then ( -}}
ENV PYTHON_SHA256 {{ .checksums.source.sha256 }}
{{ ) else "" end -}}

RUN set -eux; \
	\
{{ if is_alpine then ( -}}
	apk add --no-cache --virtual .build-deps \
		gnupg \
		tar \
		xz \
		\
		bluez-dev \
		bzip2-dev \
		dpkg-dev dpkg \
		findutils \
		gcc \
		gdbm-dev \
		libc-dev \
		libffi-dev \
		libnsl-dev \
		libtirpc-dev \
		linux-headers \
		make \
		ncurses-dev \
		openssl-dev \
		pax-utils \
		readline-dev \
		sqlite-dev \
		tcl-dev \
		tk \
		tk-dev \
		util-linux-dev \
		xz-dev \
		zlib-dev \
	; \
	\
{{ ) elif is_slim then ( -}}
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		dpkg-dev \
		gcc \
		gnupg \
		libbluetooth-dev \
		libbz2-dev \
		libc6-dev \
		libdb-dev \
		libffi-dev \
		libgdbm-dev \
		liblzma-dev \
		libncursesw5-dev \
		libreadline-dev \
		libsqlite3-dev \
		libssl-dev \
		make \
		tk-dev \
		uuid-dev \
		wget \
		xz-utils \
		zlib1g-dev \
	; \
	\
{{ ) else "" end -}}
	wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"; \
{{ if .checksums.source.sha256 then ( -}}
	echo "$PYTHON_SHA256 *python.tar.xz" | sha256sum -c -; \
{{ ) else "" end -}}
{{ if should_pgp then ( -}}
	wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc"; \
	GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$GPG_KEY"; \
	gpg --batch --verify python.tar.xz.asc python.tar.xz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" python.tar.xz.asc; \
{{ ) else "" end -}}
	mkdir -p /usr/src/python; \
	tar --extract --directory /usr/src/python --strip-components=1 --file python.tar.xz; \
	rm python.tar.xz; \
	\
	cd /usr/src/python; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	./configure \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
{{
	# https://github.com/docker-library/python/pull/980 (fixing PGO runs tests that fail, but shouldn't)
	# https://github.com/python/cpython/issues/90548 (alpine failures; not likely to be fixed any time soon)
	if is_alpine then "" else (
-}}
		--enable-optimizations \
{{ ) end -}}
		--enable-option-checking=fatal \
		--enable-shared \
{{
	# <3.10 does not have -fno-semantic-interposition enabled and --with-lto does nothing for performance
	# skip LTO on riscv64: https://github.com/docker-library/python/pull/935, https://github.com/docker-library/python/pull/1038
	if rcVersion == "3.9" then "" else (
-}}
		$(test "${gnuArch%%-*}" != 'riscv64' && echo '--with-lto') \
{{ ) end -}}
		--with-ensurepip \
	; \
	nproc="$(nproc)"; \
{{ if is_alpine then ( -}}
# set thread stack size to 1MB so we don't segfault before we hit sys.getrecursionlimit()
# https://github.com/alpinelinux/aports/commit/2026e1259422d4e0cf92391ca2d3844356c649d0
	EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000"; \
{{ ) else ( -}}
	EXTRA_CFLAGS="$(dpkg-buildflags --get CFLAGS)"; \
	LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"; \
{{ ) end -}}
{{ if is_slim or is_alpine then ( -}}
	LDFLAGS="${LDFLAGS:--Wl},--strip-all"; \
{{ ) else "" end -}}
{{
	# Enabling frame-pointers only makes sense for Python 3.12 and newer as those have perf profiler support
	if rcVersion | IN("3.9", "3.10", "3.11") then "" else (
-}}
{{ if is_alpine then ( -}}
		arch="$(apk --print-arch)"; \
{{ ) else ( -}}
		arch="$(dpkg --print-architecture)"; arch="${arch##*-}"; \
{{ ) end -}}
# https://docs.python.org/3.12/howto/perf_profiling.html
# https://github.com/docker-library/python/pull/1000#issuecomment-2597021615
		case "$arch" in \
{{ if is_alpine then ( -}}
			x86_64|aarch64) \
{{ ) else ( -}}
			amd64|arm64) \
{{ ) end -}}
				# only add "-mno-omit-leaf" on arches that support it
				# https://gcc.gnu.org/onlinedocs/gcc-14.2.0/gcc/x86-Options.html#index-momit-leaf-frame-pointer-2
				# https://gcc.gnu.org/onlinedocs/gcc-14.2.0/gcc/AArch64-Options.html#index-momit-leaf-frame-pointer
				EXTRA_CFLAGS="${EXTRA_CFLAGS:-} -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer"; \
				;; \
{{ if is_alpine then ( -}}
			x86) \
{{ ) else ( -}}
			i386) \
{{ ) end -}}
				# don't enable frame-pointers on 32bit x86 due to performance drop.
				;; \
			*) \
				# other arches don't support "-mno-omit-leaf"
				EXTRA_CFLAGS="${EXTRA_CFLAGS:-} -fno-omit-frame-pointer"; \
				;; \
		esac; \
{{ ) end -}}
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:-}" \
	; \
# https://github.com/docker-library/python/issues/784
# prevent accidental usage of a system installed libpython of the same version
	rm python; \
	make -j "$nproc" \
		"EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
		"LDFLAGS=${LDFLAGS:--Wl},-rpath='\$\$ORIGIN/../lib'" \
		python \
	; \
	make install; \
{{ if is_alpine or is_slim then "" else ( -}}
	\
# enable GDB to load debugging data: https://github.com/docker-library/python/pull/701
	bin="$(readlink -ve /usr/local/bin/python3)"; \
	dir="$(dirname "$bin")"; \
	mkdir -p "/usr/share/gdb/auto-load/$dir"; \
	cp -vL Tools/gdb/libpython.py "/usr/share/gdb/auto-load/$bin-gdb.py"; \
{{ ) end -}}
	\
	cd /; \
	rm -rf /usr/src/python; \
	\
	find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
			-o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name 'libpython*.a' \) \) \
		\) -exec rm -rf '{}' + \
	; \
	\
{{ if is_alpine then ( -}}
	find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec scanelf --needed --nobanner --format '%n#p' '{}' ';' \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
		| xargs -rt apk add --no-network --virtual .python-rundeps \
	; \
	apk del --no-network .build-deps; \
{{ ) else ( -}}
	ldconfig; \
{{ if is_slim then ( -}}
	\
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec ldd '{}' ';' \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -rt dpkg-query --search \
# https://manpages.debian.org/bookworm/dpkg/dpkg-query.1.en.html#S (we ignore diversions and it'll be really unusual for more than one package to provide any given .so file)
		| awk 'sub(":$", "", $1) { print $1 }' \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	{{ clean_apt }}; \
{{ ) else "" end -}}
{{ ) end -}}
	\
	export PYTHONDONTWRITEBYTECODE=1; \
	python3 --version; \
{{ if .setuptools then ( -}}
	\
	pip3 install \
		--disable-pip-version-check \
		--no-cache-dir \
		--no-compile \
		{{ "setuptools==\( .setuptools.version )" | @sh }} \
		# https://github.com/docker-library/python/issues/1023
		'wheel<0.46' \
	; \
{{ ) else "" end -}}
	pip3 --version

# make some useful symlinks that are expected to exist ("/usr/local/bin/python" and friends)
RUN set -eux; \
	for src in idle3 pip3 pydoc3 python3 python3-config; do \
		dst="$(echo "$src" | tr -d 3)"; \
		[ -s "/usr/local/bin/$src" ]; \
		[ ! -e "/usr/local/bin/$dst" ]; \
		ln -svT "$src" "/usr/local/bin/$dst"; \
	done

CMD ["python3"]
