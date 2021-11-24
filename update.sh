#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob

# https://www.python.org/downloads/ (under "OpenPGP Public Keys")
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

	# gpg: key 64E628F8D684696D: public key "Pablo Galindo Salgado <pablogsal@gmail.com>" imported
	[3.10]='A035C8C19219BA821ECEA86B64E628F8D684696D'
	# https://www.python.org/dev/peps/pep-0619/#release-manager-and-crew

	# gpg: key 64E628F8D684696D: public key "Pablo Galindo Salgado <pablogsal@gmail.com>" imported
	[3.11]='A035C8C19219BA821ECEA86B64E628F8D684696D'
	# https://www.python.org/dev/peps/pep-0664/#release-manager-and-crew
)

# https://github.com/docker-library/python/issues/365
# https://pypi.org/project/pip/#history
declare -A pipVersions=(
	[3.11]='21.2' # https://github.com/python/cpython/blob/v3.11.0a1/Lib/ensurepip/__init__.py -- "_PIP_VERSION"
	[3.10]='21.2' # https://github.com/python/cpython/blob/3.10/Lib/ensurepip/__init__.py -- "_PIP_VERSION"
	[3.9]='21.2' # https://github.com/python/cpython/blob/3.9/Lib/ensurepip/__init__.py -- "_PIP_VERSION"
	[3.8]='21.2' # historical
	[3.7]='21.2' # historical
	[3.6]='21.2' # historical
)
# https://pypi.org/project/setuptools/#history
declare -A setuptoolsVersions=(
	[3.11]='57' # https://github.com/python/cpython/blob/v3.11.0a1/Lib/ensurepip/__init__.py -- "_SETUPTOOLS_VERSION"
	[3.10]='57' # https://github.com/python/cpython/blob/3.10/Lib/ensurepip/__init__.py -- "_SETUPTOOLS_VERSION"
	[3.9]='57' # https://github.com/python/cpython/blob/3.9/Lib/ensurepip/__init__.py -- "_SETUPTOOLS_VERSION"
	[3.8]='57' # historical
	[3.7]='57' # historical
	[3.6]='57' # historical
)
# https://pypi.org/project/wheel/#history
# TODO wheelVersions: https://github.com/docker-library/python/issues/365#issuecomment-914669320

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

pipJson="$(curl -fsSL 'https://pypi.org/pypi/pip/json')"
setuptoolsJson="$(curl -fsSL 'https://pypi.org/pypi/setuptools/json')"

getPipCommit="$(curl -fsSL 'https://github.com/pypa/get-pip/commits/main/public/get-pip.py.atom' | tac|tac | awk -F '[[:space:]]*[<>/]+' '$2 == "id" && $3 ~ /Commit/ { print $4; exit }')"
getPipUrl="https://github.com/pypa/get-pip/raw/$getPipCommit/public/get-pip.py"
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

	pipVersion="${pipVersions[$rcVersion]}"
	pipVersion="$(
		export pipVersion
		jq <<<"$pipJson" -r '
			.releases
			| [
				keys_unsorted[]
				| select(. == env.pipVersion or startswith(env.pipVersion + "."))
			]
			| max_by(split(".") | map(tonumber))
		'
	)"
	setuptoolsVersion="${setuptoolsVersions[$rcVersion]}"
	setuptoolsVersion="$(
		export setuptoolsVersion
		jq <<<"$setuptoolsJson" -r '
			.releases
			| [
				keys_unsorted[]
				| select(. == env.setuptoolsVersion or startswith(env.setuptoolsVersion + "."))
			]
			| max_by(split(".") | map(tonumber))
		'
	)"

	echo "$version: $fullVersion (pip $pipVersion, setuptools $setuptoolsVersion)"

	for v in \
		alpine{3.15,3.14} \
		{buster,bullseye}{/slim,} \
		windows/windowsservercore-{ltsc2022,1809,ltsc2016} \
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
			-e 's/^(ENV PYTHON_SETUPTOOLS_VERSION) .*/\1 '"$setuptoolsVersion"'/' \
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

		# https://www.python.org/dev/peps/pep-0615/
		# https://mail.python.org/archives/list/python-dev@python.org/thread/PYXET7BHSETUJHSLFREM5TDZZXDTDTLY/
		if [ "$minor" -lt 9 ]; then
			sed -ri -e '/tzdata/d' "$dir/Dockerfile"
		fi

		if [ "$minor" -lt 10 ]; then
			# <3.10 does not have -fno-semantic-interposition enabled and --with-lto does nothing for performance
			sed -ri -e '/with-lto/d' "$dir/Dockerfile"
		fi
	done
done
