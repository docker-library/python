#!/bin/bash
set -e

declare -A gpgKeys=(
	# gpg: key 18ADD4FF: public key "Benjamin Peterson <benjamin@python.org>" imported
	[2.7]='C01E1CAD5EA2C4F0B8E3571504C367C218ADD4FF'
	# https://www.python.org/dev/peps/pep-0373/#release-manager-and-crew

	# gpg: key 36580288: public key "Georg Brandl (Python release signing key) <georg@python.org>" imported
	[3.3]='26DEA9D4613391EF3E25C9FF0A5B101836580288'
	# https://www.python.org/dev/peps/pep-0398/#release-manager-and-crew

	# gpg: key F73C700D: public key "Larry Hastings <larry@hastings.org>" imported
	[3.4]='97FC712E4C024BBEA48A61ED3A5CA953F73C700D'
	# https://www.python.org/dev/peps/pep-0429/#release-manager-and-crew

	# gpg: key F73C700D: public key "Larry Hastings <larry@hastings.org>" imported
	[3.5]='97FC712E4C024BBEA48A61ED3A5CA953F73C700D'
	# https://www.python.org/dev/peps/pep-0478/#release-manager-and-crew

	# gpg: key AA65421D: public key "Ned Deily (Python release signing key) <nad@acm.org>" imported
	[3.6]='0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D'
	# https://www.python.org/dev/peps/pep-0494/#release-manager-and-crew
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

pipVersion="$(curl -fsSL 'https://pypi.python.org/pypi/pip/json' | awk -F '"' '$2 == "version" { print $4 }')"

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
		if [[ "$version" != 2.* ]]; then
			for variant in \
				debian \
				alpine \
				slim \
				onbuild \
			; do
				if [ "$variant" = 'debian' ]; then
					dir="$version"
				else
					dir="$version/$variant"
				fi
				template="Dockerfile-$variant.template"
				{ generated_warning; cat "$template"; } > "$dir/Dockerfile"
			done
			if [ -d "$version/wheezy" ]; then
				cp "$version/Dockerfile" "$version/wheezy/Dockerfile"
				sed -ri 's/:jessie/:wheezy/g' "$version/wheezy/Dockerfile"
			fi
		fi
		(
			set -x
			sed -ri \
				-e 's/^(ENV GPG_KEY) .*/\1 '"${gpgKeys[$version]}"'/' \
				-e 's/^(ENV PYTHON_VERSION) .*/\1 '"$fullVersion"'/' \
				-e 's/^(ENV PYTHON_PIP_VERSION) .*/\1 '"$pipVersion"'/' \
				-e 's/^(FROM python):.*/\1:'"$version"'/' \
				"$version"/{,*/}Dockerfile
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
