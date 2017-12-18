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
				| sed -r 's!^.*refs/tags/v([0-9.]+).*$!\1!' \
				|| :

			# this page has a very aggressive varnish cache in front of it, which is why we also scrape tags from GitHub
			curl -fsSL 'https://www.python.org/ftp/python/' \
				| grep '<a href="'"$rcVersion." \
				| sed -r 's!.*<a href="([^"/]+)/?".*!\1!' \
				|| :
		} | sort -ruV
	) )
	fullVersion=
	for possible in "${possibles[@]}"; do
		possibleVersions=( $(
			curl -fsSL "https://www.python.org/ftp/python/$possible/" \
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
		alpine{3.4,3.6,3.7} \
		{wheezy,jessie,stretch}{/slim,/onbuild,} \
		windows/nanoserver-{1709,sac2016} \
		windows/windowsservercore-{1709,ltsc2016} \
	; do
		dir="$version/$v"
		variant="$(basename "$v")"

		[ -d "$dir" ] || continue

		case "$variant" in
			slim|onbuild) template="$variant"; tag="$(basename "$(dirname "$dir")")" ;;
			windowsservercore-*) template='windowsservercore'; tag="${variant#*-}" ;;
			alpine*) template='alpine'; tag="${variant#alpine}" ;;
			*) template='debian'; tag="$variant" ;;
		esac
		if [ "$variant" = 'slim' ]; then
			# use "debian:*-slim" variants for "python:*-slim" variants
			tag+='-slim'
		fi
		template="Dockerfile-${template}.template"

		if [[ "$version" == 2.* ]]; then
			echo "  TODO: vimdiff 3.6/$v/Dockerfile $version/$v/Dockerfile"
		else
			{ generated_warning; cat "$template"; } > "$dir/Dockerfile"
		fi

		sed -ri \
			-e 's/^(ENV GPG_KEY) .*/\1 '"${gpgKeys[$version]:-${gpgKeys[$rcVersion]}}"'/' \
			-e 's/^(ENV PYTHON_VERSION) .*/\1 '"$fullVersion"'/' \
			-e 's/^(ENV PYTHON_RELEASE) .*/\1 '"${fullVersion%%[a-z]*}"'/' \
			-e 's/^(ENV PYTHON_PIP_VERSION) .*/\1 '"$pipVersion"'/' \
			-e 's/^(FROM python):.*/\1:'"$version-$tag"'/' \
			-e 's!^(FROM (debian|buildpack-deps|alpine|microsoft/[^:]+)):.*!\1:'"$tag"'!' \
			"$dir/Dockerfile"

		case "$variant" in
			alpine3.4) sed -ri -e 's/libressl/openssl/g' "$dir/Dockerfile" ;;
			wheezy) sed -ri -e 's/dpkg-architecture --query /dpkg-architecture -q/g' "$dir/Dockerfile" ;;
		esac

		case "$v" in
			wheezy/slim|jessie/slim)
				sed -ri \
					-e 's/libssl1.1/libssl1.0.0/g' \
					-e 's/libreadline7/libreadline6/g' \
					"$dir/Dockerfile"
				;;
		esac

		case "$v" in
			*/onbuild) ;;
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
