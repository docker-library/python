#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
	json='{}'
else
	json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

declare -A checksums=()
check_file() {
	local dirVersion="$1"; shift
	local fullVersion="$1"; shift
	local type="${1:-source}" # "source" or "windows"

	local filename="Python-$fullVersion.tar.xz"
	if [ "$type" = 'windows' ]; then
		filename="python-$fullVersion-amd64.exe"
	fi
	local url="https://www.python.org/ftp/python/$dirVersion/$filename"

	local sigstore
	if sigstore="$(
		wget -qO- -o/dev/null "$url.sigstore" \
			| jq -r '
				.messageSignature.messageDigest
				| if .algorithm != "SHA2_256" then
					error("sigstore bundle not using SHA2_256")
				else .digest end
			'
	)" && [ -n "$sigstore" ]; then
		sigstore="$(base64 -d <<<"$sigstore" | hexdump -ve '/1 "%02x"')"
		checksums["$fullVersion"]="$(jq <<<"${checksums["$fullVersion"]:-null}" --arg type "$type" --arg sha256 "$sigstore" '.[$type].sha256 = $sha256')"
		return 0
	fi

	# TODO is this even necessary/useful?  the sigstore-based version above is *much* faster, supports all current versions (not just 3.12+ like this), *and* should be more reliable 🤔
	local sbom
	if sbom="$(
		wget -qO- -o/dev/null "$url.spdx.json" \
			| jq --arg filename "$filename" '
				first(
					.packages[]
					| select(
						.name == "CPython"
						and .packageFileName == $filename
					)
				)
				| .checksums
				| map({
					key: (.algorithm // empty | ascii_downcase),
					value: (.checksumValue // empty),
				})
				| if length < 1 then
					error("no checksums found for \($filename)")
				else . end
				| from_entries
				| if has("sha256") then . else
					error("missing sha256 for \($filename); have \(.)")
				end
			'
	)" && [ -n "sbom" ]; then
		checksums["$fullVersion"]="$(jq <<<"${checksums["$fullVersion"]:-null}" --arg type "$type" --argjson sums "$sbom" '.[$type] += $sums')"
		return 0
	fi

	if ! wget -q -O /dev/null -o /dev/null --spider "$url"; then
		return 1
	fi

	return 0
}

for version in "${versions[@]}"; do
	rcVersion="${version%-rc}"
	export version rcVersion

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
			wget -qO- 'https://www.python.org/ftp/python/' \
				| grep '<a href="'"$rcVersion." \
				| sed -r 's!.*<a href="([^"/]+)/?".*!\1!' \
				| grep $rcGrepV -E -- '[a-zA-Z]+' \
				|| :
		} | sort -ruV
	) )
	fullVersion=
	hasWindows=
	declare -A impossible=()
	for possible in "${possibles[@]}"; do
		rcPossible="${possible%%[a-z]*}"

		# varnish is great until it isn't (usually the directory listing we scrape below is updated/uncached significantly later than the release being available)
		if check_file "$rcPossible" "$possible"; then
			fullVersion="$possible"
			if check_file "$rcPossible" "$possible" windows; then
				hasWindows=1
			fi
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
			if check_file "$rcPossible" "$possibleVersion"; then
				fullVersion="$possibleVersion"
				if check_file "$rcPossible" "$possible" windows; then
					hasWindows=1
				fi
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

	ensurepipVersions="$(
		wget -qO- "https://github.com/python/cpython/raw/v$fullVersion/Lib/ensurepip/__init__.py" \
			| grep -E '^[^[:space:]]+_VERSION[[:space:]]*='
	)"

	# Note: We don't extract the pip version here, since our policy is now to use the pip version
	# that is installed during the Python build (which is the version bundled in ensurepip), and
	# to not support overriding it.

	# TODO remove setuptools version handling entirely once Python 3.11 is EOL
	setuptoolsVersion="$(sed -nre 's/^_SETUPTOOLS_VERSION[[:space:]]*=[[:space:]]*"(.*?)".*/\1/p' <<<"$ensurepipVersions")"
	case "$rcVersion" in
		3.10 | 3.11)
			if [ -z "$setuptoolsVersion" ]; then
				echo >&2 "error: $version: missing setuptools version"
				exit 1
			fi
			if ! wget -q -O /dev/null -o /dev/null --spider "https://pypi.org/pypi/setuptools/$setuptoolsVersion/json"; then
				echo >&2 "error: $version: setuptools version ($setuptoolsVersion) seems to be invalid?"
				exit 1
			fi
			;;

		*)
			# https://github.com/python/cpython/issues/95299 -> https://github.com/python/cpython/commit/ece20dba120a1a4745721c49f8d7389d4b1ee2a7
			if [ -n "$setuptoolsVersion" ]; then
				echo >&2 "error: $version: unexpected setuptools: $setuptoolsVersion"
				exit 1
			fi
			;;
	esac

	echo "$version: $fullVersion"

	export fullVersion pipVersion setuptoolsVersion hasWindows
	doc="$(jq -nc '
		{
			version: env.fullVersion,
			variants: [
				(
					"trixie",
					"bookworm",
					empty
				| ., "slim-" + .), # https://github.com/docker-library/ruby/pull/142#issuecomment-320012893
				(
					"3.23",
					"3.22",
					empty
				| "alpine" + .),
				if env.hasWindows != "" then
					(
						"ltsc2025",
						"ltsc2022",
						empty
					| "windows/windowsservercore-" + .)
				else empty end
			],
		} + if env.setuptoolsVersion != "" then {
			setuptools: {
				version: env.setuptoolsVersion,
			},
		} else {} end
	')"

	if [ -n "${checksums["$fullVersion"]:-}" ]; then
		doc="$(jq <<<"$doc" -c --argjson checksums "${checksums["$fullVersion"]}" '.checksums = $checksums')"
	fi

	json="$(jq <<<"$json" -c --argjson doc "$doc" '.[env.version] = $doc')"
done

jq <<<"$json" -S . > versions.json
