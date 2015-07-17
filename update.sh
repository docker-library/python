#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

pipVersion="$(curl -sSL 'https://pypi.python.org/pypi/pip/json' | awk -F '"' '$2 == "version" { print $4 }')"

for version in "${versions[@]}"; do
	# <span class="release-number"><a href="/downloads/release/python-278/">Python 2.7.8</a></span>
	# <span class="release-number"><a href="/downloads/release/python-341/">Python 3.4.1</a></span>
	fullVersion="$(curl -sSL 'https://www.python.org/downloads/' | awk -F 'Python |</a>' '/<span class="release-number"><a[^>]+>Python '"$version"'./ { print $2 }' | grep -v 'rc' | sort -V | tail -1)"
	# TODO figure out a better want to handle RCs than just filtering them out wholesale
	if [ -z "$fullVersion" ]; then
		echo >&2 "warning: cannot find $version"
		continue
	fi
	(
		set -x
		sed -ri '
			s/^(ENV PYTHON_VERSION) .*/\1 '"$fullVersion"'/;
			s/^(ENV PYTHON_PIP_VERSION) .*/\1 '"$pipVersion"'/;
		' "$version"/{,slim/,wheezy/}Dockerfile
		sed -ri 's/^(FROM python):.*/\1:'"$version"'/' "$version/onbuild/Dockerfile"
	)
done
