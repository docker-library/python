#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob

declare -A gpgKeys=(
	# gpg: key 18ADD4FF: public key "Benjamin Peterson <benjamin@python.org>" imported
	[2.7]='C01E1CAD5EA2C4F0B8E3571504C367C218ADD4FF'
	# https://www.python.org/dev/peps/pep-0373/#release-manager-and-crew

	# gpg: key F73C700D: public key "Larry Hastings <larry@hastings.org>" imported
	[3.4]='97FC712E4C024BBEA48A61ED3A5CA953F73C700D'
	# https://www.python.org/dev/peps/pep-0429/#release-manager-and-crew

	# gpg: key F73C700D: public key "Larry Hastings <larry@hastings.org>" imported
	[3.5]='97FC712E4C024BBEA48A61ED3A5CA953F73C700D'
	# https://www.python.org/dev/peps/pep-0478/#release-manager-and-crew

	# gpg: key AA65421D: public key "Ned Deily (Python release signing key) <nad@acm.org>" imported
	[3.6]='0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D'
	# https://www.python.org/dev/peps/pep-0494/#release-manager-and-crew

	# gpg: key AA65421D: public key "Ned Deily (Python release signing key) <nad@acm.org>" imported
	[3.7]='0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D'
	# https://www.python.org/dev/peps/pep-0494/#release-manager-and-crew
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

pipVersion="$(curl -fsSL 'https://pypi.org/pypi/pip/json' | jq -r .info.version)"

generated_warning() {
	cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#

	EOH
}

travisEnv=
appveyorEnv=
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
		rcPossible="${possible%[a-z]*}"

		# varnish is great until it isn't
		if wget -q -O /dev/null -o /dev/null --spider "https://www.python.org/ftp/python/$rcPossible/Python-$possible.tar.xz"; then
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
		if [ "${#possibleVersions[@]}" -gt 0 ]; then
			fullVersion="${possibleVersions[0]}"
			break
		fi
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
		alpine{3.8,3.9} \
		{wheezy,jessie,stretch}{/slim,} \
		windows/nanoserver-{1709,sac2016} \
		windows/windowsservercore-{1709,ltsc2016} \
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
		if [[ "$version" == 2.* ]]; then
			template="caveman-${template}"
		fi
		template="Dockerfile-${template}.template"

		{ generated_warning; cat "$template"; } > "$dir/Dockerfile"

		sed -ri \
			-e 's/^(ENV GPG_KEY) .*/\1 '"${gpgKeys[$version]:-${gpgKeys[$rcVersion]}}"'/' \
			-e 's/^(ENV PYTHON_VERSION) .*/\1 '"$fullVersion"'/' \
			-e 's/^(ENV PYTHON_RELEASE) .*/\1 '"${fullVersion%%[a-z]*}"'/' \
			-e 's/^(ENV PYTHON_PIP_VERSION) .*/\1 '"$pipVersion"'/' \
			-e 's/^(FROM python):.*/\1:'"$version-$tag"'/' \
			-e 's!^(FROM (debian|buildpack-deps|alpine|[^/]+/windows/[^:]+)):.*!\1:'"$tag"'!' \
			"$dir/Dockerfile"

		case "$variant" in
			wheezy) sed -ri -e 's/dpkg-architecture --query /dpkg-architecture -q/g' "$dir/Dockerfile" ;;
		esac

		# Alpine < 3.9 used libressl instead of openssl
		if [ "$v" = 'alpine3.8' ]; then
			sed -ri -e 's/openssl/libressl/g' "$dir/Dockerfile"
		fi

		case "$version/$v" in
			# https://bugs.python.org/issue32598 (Python 3.7.0b1+)
			# TL;DR: Python 3.7+ uses OpenSSL functionality which LibreSSL 2.6.x in Alpine 3.7 doesn't implement
			# Python 3.5 on Alpine 3.8 needs OpenSSL too
			3.5*/alpine3.8)
				sed -ri -e 's/libressl-dev/openssl-dev/g' "$dir/Dockerfile"
				;;& # (3.5*/alpine* needs to match the next block too)

			# Libraries to build the nis module only available in Alpine 3.7+.
			# Also require this patch https://bugs.python.org/issue32521 only available in Python 2.7, 3.6+.
			3.[4-5]*/alpine*)
				sed -ri -e '/libnsl-dev/d' -e '/libtirpc-dev/d' "$dir/Dockerfile"
				;;& # (3.4*/alpine* and 3.5*/alpine* need to match the next blocks too)

			# Alpine 3.9's OpenSSL 1.1.1 is too new for Python 3.4
			# no OpenSSL 1.0.x package available, so have to switch back to LibreSSL
			3.4/alpine3.9)
				sed -ri -e 's/openssl-dev/libressl-dev/g' "$dir/Dockerfile"
				;;& # (need to match next block too)

			# https://bugs.python.org/issue11063, https://bugs.python.org/issue20519 (Python 3.7.0+)
			# A new native _uuid module improves uuid import time and avoids using ctypes.
			# This requires the development libuuid headers.
			3.[4-6]*/alpine*)
				sed -ri -e '/util-linux-dev/d' "$dir/Dockerfile"
				;;
			3.[4-6]*)
				sed -ri -e '/uuid-dev/d' "$dir/Dockerfile"
				;;& # (other Debian variants need to match later blocks)

			3.4/stretch*)
				# older Python needs older OpenSSL
				sed -ri -e 's/libssl-dev/libssl1.0-dev/g' "$dir/Dockerfile"
				;;
			*/stretch | */jessie | */wheezy)
				# buildpack-deps already includes libssl-dev
				sed -ri -e '/libssl-dev/d' "$dir/Dockerfile"
				;;
		esac

		case "$v" in
			windows/*-1709) ;; # no AppVeyor support for 1709 yet: https://github.com/appveyor/ci/issues/1885
			windows/*)
				appveyorEnv='\n    - version: '"$version"'\n      variant: '"$variant$appveyorEnv"
				;;
			*)
				travisEnv='\n  - VERSION='"$version VARIANT=$v$travisEnv"
				;;
		esac
	done
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml

appveyor="$(awk -v 'RS=\n\n' '$1 == "environment:" { $0 = "environment:\n  matrix:'"$appveyorEnv"'" } { printf "%s%s", $0, RS }' .appveyor.yml)"
echo "$appveyor" > .appveyor.yml
