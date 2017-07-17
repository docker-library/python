#!/usr/bin/env bash
set -Eeuo pipefail

declare -A aliases=(
	[3.6-rc]='rc'
	[3.6]='3 latest'
	[2.7]='2'
)

defaultDebianSuite='stretch'
declare -A debianSuites=(
	[2.7]='jessie'
	[3.3]='jessie'
	[3.4]='jessie'
	[3.5]='jessie'
	[3.6]='jessie'
)
defaultAlpineVersion='3.4'
declare -A alpineVersions=(
	[2.7]='3.4'
	[3.3]='3.4'
	[3.4]='3.4'
	[3.5]='3.4'
	[3.6]='3.4'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( */ )
versions=( "${versions[@]%/}" )

# sort version numbers with highest first
IFS=$'\n'; versions=( $(echo "${versions[*]}" | sort -rV) ); unset IFS

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		fileCommit \
			Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						print $i
					}
				}
			')
	)
}

getArches() {
	local repo="$1"; shift
	local officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/'

	eval "declare -g -A parentRepoToArches=( $(
		find -name 'Dockerfile' -exec awk '
				toupper($1) == "FROM" && $2 !~ /^('"$repo"'|scratch|microsoft\/[^:]+)(:|$)/ {
					print "'"$officialImagesUrl"'" $2
				}
			' '{}' + \
			| sort -u \
			| xargs bashbrew cat --format '[{{ .RepoName }}:{{ .TagName }}]="{{ join " " .TagEntry.Architectures }}"'
	) )"
}
getArches 'python'

cat <<-EOH
# this file is generated via https://github.com/docker-library/python/blob/$(fileCommit "$self")/$self

Maintainers: Tianon Gravi <admwiggin@gmail.com> (@tianon),
             Joseph Ferguson <yosifkit@gmail.com> (@yosifkit)
GitRepo: https://github.com/docker-library/python.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version in "${versions[@]}"; do
	debianSuite="${debianSuites[$version]:-$defaultDebianSuite}"
	alpineVersion="${alpineVersions[$version]:-$defaultAlpineVersion}"

	for v in \
		{stretch,jessie,wheezy}{,/slim,/onbuild} \
		alpine{3.6,3.4} \
		windows/windowsservercore windows/nanoserver \
		onbuild \
	; do
		dir="$version/$v"
		variant="$(basename "$v")"

		[ -f "$dir/Dockerfile" ] || continue

		commit="$(dirCommit "$dir")"

		versionDockerfile="$dir/Dockerfile"
		if [ "$variant" = 'onbuild' ]; then
			versionDockerfile="$(dirname "$dir")/Dockerfile"
		fi
		fullVersion="$(git show "$commit":"$versionDockerfile" | awk '$1 == "ENV" && $2 == "PYTHON_VERSION" { print $3; exit }')"

		versionAliases=(
			$fullVersion
			$version
			${aliases[$version]:-}
		)

		variantAliases=( "${versionAliases[@]/%/-$variant}" )
		if [ "$variant" = "$debianSuite" ]; then
			variantAliases+=( "${versionAliases[@]}" )
		elif [ "$variant" = "alpine${alpineVersion}" ]; then
			variantAliases+=( "${versionAliases[@]/%/-alpine}" )
		fi
		variantAliases=( "${variantAliases[@]//latest-/}" )

		case "$v" in
			windows/*) variantArches='windows-amd64' ;;
			*/onbuild)
				variantParent="$(awk 'toupper($1) == "FROM" { print $2 }' "$(dirname "$dir")/Dockerfile")"
				variantArches="${parentRepoToArches[$variantParent]}"
				;;
			*)
				variantParent="$(awk 'toupper($1) == "FROM" { print $2 }' "$dir/Dockerfile")"
				variantArches="${parentRepoToArches[$variantParent]}"
				;;
		esac

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			Architectures: $(join ', ' $variantArches)
			GitCommit: $commit
			Directory: $dir
		EOE
		[ "$variant" = "$v" ] || echo "Constraints: $variant"
	done
done
