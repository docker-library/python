#!/bin/bash
set -e

declare -A aliases
aliases=(
	[3.4]='3 latest'
	[2.7]='2'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( */ )
versions=( "${versions[@]%/}" )
url='git://github.com/docker-library/python'

echo '# maintainer: InfoSiftr <github@infosiftr.com> (@infosiftr)'

for version in "${versions[@]}"; do
	commit="$(git log -1 --format='format:%H' -- "$version")"
	fullVersion="$(grep -m1 'ENV PYTHON_VERSION ' "$version/Dockerfile" | cut -d' ' -f3)"
	
	versionAliases=()
	while [ "$fullVersion" != "$version" -a "${fullVersion%[.a-z-]*}" != "$fullVersion" ]; do
		versionAliases+=( $fullVersion )
		fullVersion="${fullVersion%[.a-z-]*}"
	done
	versionAliases+=( $version ${aliases[$version]} )
	
	echo
	for va in "${versionAliases[@]}"; do
		echo "$va: ${url}@${commit} $version"
	done
	
	for variant in onbuild slim wheezy; do
		[ -f "$version/$variant/Dockerfile" ] || continue
		commit="$(git log -1 --format='format:%H' -- "$version/$variant")"
		echo
		for va in "${versionAliases[@]}"; do
			if [ "$va" = 'latest' ]; then
				va="$variant"
			else
				va="$va-$variant"
			fi
			echo "$va: ${url}@${commit} $version/$variant"
		done
	done
done
