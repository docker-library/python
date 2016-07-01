#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

pipVersion="$(curl -fsSL 'https://pypi.python.org/pypi/pip/json' | awk -F '"' '$2 == "version" { print $4 }')"

travisEnv=
for version in "${versions[@]}"; do
	# <span class="release-number"><a href="/downloads/release/python-278/">Python 2.7.8</a></span>
	# <span class="release-number"><a href="/downloads/release/python-341/">Python 3.4.1</a></span>
	fullVersion="$(curl -fsSL 'https://www.python.org/downloads/' | awk -F 'Python |</a>' '/<span class="release-number"><a[^>]+>Python '"$version"'./ { print $2 }' | grep -v 'rc' | sort -V | tail -1)"
	# TODO figure out a better way to handle RCs than just filtering them out
	if [ -z "$fullVersion" ]; then
		{
			echo
			echo
			echo "  warning: cannot find $version (alpha/beta/rc?)"
			echo
			echo
		} >&2
	else
		(
			set -x
			sed -ri '
				s/^(ENV PYTHON_VERSION) .*/\1 '"$fullVersion"'/;
				s/^(ENV PYTHON_PIP_VERSION) .*/\1 '"$pipVersion"'/;
			' "$version"/{,*/}Dockerfile
			sed -ri 's/^(FROM python):.*/\1:'"$version"'/' "$version/onbuild/Dockerfile"
		)
	fi
	for variant in wheezy alpine slim; do
		[ -d "$version/$variant" ] || continue
		travisEnv='\n  - VERSION='"$version VARIANT=$variant$travisEnv"
	done
	travisEnv='\n  - VERSION='"$version VARIANT=$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
