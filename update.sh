#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob

# https://www.python.org/downloads/23Introduction (under "OpenPGP Public Keys")
declare -A gpgKeys=(
	# gpg: key AA65421D: public key "Ned Deily (Python release signing key) <nad@acm.org>" imported
	[3.6]='0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D'
	# https://www.python.org/dev/peps/pep-0494/#release-manager-and-crew

	# gpg: key AA65421D: public key "Ned Deily (Python release signing key) <nad@acm.org>" imported
	[3.7]='0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D'
	# https://www.python.org/dev/peps/pep-0537/#release-manager-and-crew

	# gpg: key B26995E310250568: public key "\xc5\x81ukasz Langa (GPG langa.pl) <lukasz@langa.pl>" imported
	[3.8]='E3FF2839C048B25C084DEBE9B26995E310250568'
	# https://www.python.org/dev/peps/pep-0569/#release-manager-and-crew

	# gpg: key B26995E310250568: public key "\xc5\x81ukasz Langa (GPG langa.pl) <lukasz@langa.pl>" imported
	[3.9]='E3FF2839C048B25C084DEBE9B26995E310250568'
	# https://www.python.org/dev/peps/pep-0596/#release-manager-and-crew
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

pipVersion="$(curl -fsSL 'https://pypi.org/pypi/pip/json' | jq -r .info.version)"
getPipCommit="$(curl -fsSL 'https://github.com/pypa/get-pip/commits/master/get-pip.py.atom' | tac|tac | awk -F '[[:space:]]*[<>/]+' '$2 == "id" && $3 ~ /Commit/ { print $4; exit }')"
getPipUrl="https://github.com/pypa/get-pip/raw/$getPipCommit/get-pip.py"
getPipSha256="$(curl -fsSL "$getPipUrl" | sha256sum | cut -d' ' -f1)"

generated_warning() {
	cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#

	EOH
}

is_good_version() {
	local dir="$1"; shift
	local dirVersion="$1"; shift
	local fullVersion="$1"; shift

	if ! wget -q -O /dev/null -o /dev/null --spider "https://www.python.org/ftp/python/$dirVersion/Python-$fullVersion.tar.xz"; then
		return 1
	fi

	if [ -d "$dir/windows" ] && ! wget -q -O /dev/null -o /dev/null --spider "https://www.python.org/ftp/python/$dirVersion/python-$fullVersion-amd64.exe"; then
		return 1
	fi

	return 0
}

for version in "${versions[@]}"; do
	rcVersion="${version%-rc}"
	rcGrepV='-v'
	if [ "$rcVersion" != "$version" ]; then
		rcGrepV=
	fi

	possibles=( $(
		{
			git ls-remote --tags https://github.com/python/cpython.git "refs/tags/v${rcVersion}.*" \
				| sed -r 's!^.*refs/tags/v([0-9a-z.]+).*$!\1!' \
				| grep $rcGrepV -E -- '[a-zA-Z]+' \
				|| :

			# this page has a very aggressive varnish cache in front of it, which is why we also scrape tags from GitHub
			curl -fsSL 'https://www.python.org/ftp/python/' \
				| grep '<a href="'"$rcVersion." \
				| sed -r 's!.*<a href="([^"/]+)/?".*!\1!' \
				| grep $rcGrepV -E -- '[a-zA-Z]+' \
				|| :
		} | sort -ruV
	) )
	fullVersion=
	declare -A impossible=()
	for possible in "${possibles[@]}"; do
		rcPossible="${possible%%[a-z]*}"

		# varnish is great until it isn't (usually the directory listing we scrape below is updated/uncached significantly later than the release being available)
		if is_good_version "$version" "$rcPossible" "$possible"; then
			fullVersion="$possible"
			break
		fi

		if [ -n "${impossible[$rcPossible]:-}" ]; then
			continue
		fi
		impossible[$rcPossible]=1
		possibleVersions=( $(
			wget -qO- -o /dev/null "https://www.python.org/ftp/python/$rcPossible/" \
				| grep '<a href="Python-'"$rcVersion"'.*\.tar\.xz"' \
				| sed -r 's!.*<a href="Python-([^"/]+)\.tar\.xz".*!\1!' \
				| grep $rcGrepV -E -- '[a-zA-Z]+' \
				| sort -rV \
				|| true
		) )
		for possibleVersion in "${possibleVersions[@]}"; do
			if is_good_version "$version" "$rcPossible" "$possibleVersion"; then
				fullVersion="$possibleVersion"
				break
			fi
		done
	done

	if [ -z "$fullVersion" ]; then
		{
			echo
			echo
			echo "  error: cannot find $version (alpha/beta/rc?)"
			echo
			echo
		} >&2
		exit 1
	fi

	echo "$version: $fullVersion"

	for v in \
		alpine{3.11,3.12} \
		{stretch,buster}{/slim,} \
		windows/windowsservercore-{1809,ltsc2016} \
	; do
		dir="$version/$v"
		variant="$(basename "$v")"

		[ -d "$dir" ] || continue

		case "$variant" in
			slim) template="$variant"; tag="$(basename "$(dirname "$dir")")" ;;
			windowsservercore-*) template='windowsservercore'; tag="${variant#*-}" ;;
			alpine*) template='alpine'; tag="${variant#alpine}" ;;
			*) template='debian'; tag="$variant" ;;
		esac
		if [ "$variant" = 'slim' ]; then
			# use "debian:*-slim" variants for "python:*-slim" variants
			tag+='-slim'
		fi
		template="Dockerfile-${template}.template"

		{ generated_warning; cat "$template"; } > "$dir/Dockerfile"

		sed -ri \
			-e 's/^(ENV GPG_KEY) .*/\1 '"${gpgKeys[$version]:-${gpgKeys[$rcVersion]}}"'/' \
			-e 's/^(ENV PYTHON_VERSION) .*/\1 '"$fullVersion"'/' \
			-e 's/^(ENV PYTHON_RELEASE) .*/\1 '"${fullVersion%%[a-z]*}"'/' \
			-e 's/^(ENV PYTHON_PIP_VERSION) .*/\1 '"$pipVersion"'/' \
			-e 's!^(ENV PYTHON_GET_PIP_URL) .*!\1 '"$getPipUrl"'!' \
			-e 's!^(ENV PYTHON_GET_PIP_SHA256) .*!\1 '"$getPipSha256"'!' \
			-e 's/^(FROM python):.*/\1:'"$version-$tag"'/' \
			-e 's!^(FROM (debian|buildpack-deps|alpine|mcr[.]microsoft[.]com/[^:]+)):.*!\1:'"$tag"'!' \
			"$dir/Dockerfile"

		case "$rcVersion/$v" in
			# https://bugs.python.org/issue11063, https://bugs.python.org/issue20519 (Python 3.7.0+)
			# A new native _uuid module improves uuid import time and avoids using ctypes.
			# This requires the development libuuid headers.
			3.6/alpine*)
				sed -ri -e '/util-linux-dev/d' "$dir/Dockerfile"
				;;
			3.6/*)
				sed -ri -e '/uuid-dev/d' "$dir/Dockerfile"
				;;
		esac

		major="${rcVersion%%.*}"
		minor="${rcVersion#$major.}"
		minor="${minor%%.*}"
		if [ "$minor" -ge 8 ]; then
			# PROFILE_TASK has a reasonable default starting in 3.8+; see:
			#   https://bugs.python.org/issue36044
			#   https://github.com/python/cpython/pull/14702
			#   https://github.com/python/cpython/pull/14910
			perl -0 -i -p -e "s![^\n]+PROFILE_TASK(='[^']+?')?[^\n]+\n!!gs" "$dir/Dockerfile"
		fi
		if [ "$minor" -ge 9 ]; then
			# "wininst-*.exe" is not installed for Unix platforms on Python 3.9+: https://github.com/python/cpython/pull/14511
			sed -ri -e '/wininst/d' "$dir/Dockerfile"
		fi
	done
done
