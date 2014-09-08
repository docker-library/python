#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
	fullVersion="$(curl -sSL 'https://www.python.org/ftp/python/' | grep '<a href="'"$version." | sed -r 's!.*<a href="([^"/]+)/?".*!\1!' | sort -V | tail -1)"
	(
		set -x
		sed -ri 's/^(ENV PYTHON_VERSION) .*/\1 '"$fullVersion"'/' "$version/Dockerfile"
		sed -ri 's/^(FROM python):.*/\1:'"$fullVersion"'/' "$version/onbuild/Dockerfile"
	)
done
