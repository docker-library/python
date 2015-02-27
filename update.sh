#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
	# <span class="release-number"><a href="/downloads/release/python-278/">Python 2.7.8</a></span>
	# <span class="release-number"><a href="/downloads/release/python-341/">Python 3.4.1</a></span>
	fullVersion="$(curl -sSL 'https://www.python.org/downloads/' | awk -F 'Python |</a>' '/<span class="release-number"><a[^>]+>Python '"$version"'./ { print $2 }' | grep -v 'rc' | sort -V | tail -1)"
	# TODO figure out a better want to handle RCs than just filtering them out wholesale
	(
		set -x
		sed -ri 's/^(ENV PYTHON_VERSION) .*/\1 '"$fullVersion"'/' "$version"/{,slim/,wheezy/}Dockerfile
		sed -ri 's/^(FROM python):.*/\1:'"$fullVersion"'/' "$version/onbuild/Dockerfile"
	)
done
