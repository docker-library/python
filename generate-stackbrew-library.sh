#!/usr/bin/env bash
set -Eeuo pipefail

declare -A aliases=(
	[3.14]='3 latest'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

# sort version numbers with highest first
IFS=$'\n'; set -- $(sort -rV <<<"$*"); unset IFS

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		files="$(
			git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						if ($i ~ /^--from=/) {
							next
						}
						print $i
					}
				}
			'
		)"
		fileCommit Dockerfile $files
	)
}

getArches() {
	local repo="$1"; shift
	local officialImagesBase="${BASHBREW_LIBRARY:-https://github.com/docker-library/official-images/raw/HEAD/library}/"

	local parentRepoToArchesStr
	parentRepoToArchesStr="$(
		find -name 'Dockerfile' -exec awk -v officialImagesBase="$officialImagesBase" '
				toupper($1) == "FROM" && $2 !~ /^('"$repo"'|scratch|.*\/.*)(:|$)/ {
					printf "%s%s\n", officialImagesBase, $2
				}
			' '{}' + \
			| sort -u \
			| xargs -r bashbrew cat --format '["{{ .RepoName }}:{{ .TagName }}"]="{{ join " " .TagEntry.Architectures }}"'
	)"
	eval "declare -g -A parentRepoToArches=( $parentRepoToArchesStr )"
}
getArches 'python'

cat <<-EOH
# this file is generated via https://github.com/docker-library/python/blob/$(fileCommit "$self")/$self

Maintainers: Tianon Gravi <admwiggin@gmail.com> (@tianon),
             Joseph Ferguson <yosifkit@gmail.com> (@yosifkit)
GitRepo: https://github.com/docker-library/python.git
Builder: buildkit
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version; do
	export version
	variants="$(jq -r '.[env.version].variants | map(@sh) | join(" ")' versions.json)"
	eval "variants=( $variants )"

	fullVersion="$(jq -r '.[env.version].version' versions.json)"

	versionAliases=(
		$fullVersion
		$version
		${aliases[$version]:-}
	)

	defaultDebianVariant="$(jq -r '
		.[env.version].variants
		| map(select(
			startswith("alpine")
			or startswith("slim-")
			or startswith("windows/")
			| not
		))
		| .[0]
	' versions.json)"
	defaultAlpineVariant="$(jq -r '
		.[env.version].variants
		| map(select(
			startswith("alpine")
		))
		| .[0]
	' versions.json)"

	for v in "${variants[@]}"; do
		dir="$version/$v"
		[ -f "$dir/Dockerfile" ] || continue
		variant="$(basename "$v")"

		commit="$(dirCommit "$dir")"

		variantAliases=( "${versionAliases[@]/%/-$variant}" )
		case "$variant" in
			*-"$defaultDebianVariant") # slim-xxx -> slim
				variantAliases+=( "${versionAliases[@]/%/-${variant%-$defaultDebianVariant}}" )
				;;
			"$defaultAlpineVariant")
				variantAliases+=( "${versionAliases[@]/%/-alpine}" )
				;;
		esac
		variantAliases=( "${variantAliases[@]//latest-/}" )

		case "$v" in
			windows/*)
				variantArches='windows-amd64'
				;;

			*)
				variantParent="$(awk 'toupper($1) == "FROM" { print $2 }' "$dir/Dockerfile")"
				variantArches="${parentRepoToArches[$variantParent]}"
				;;
		esac

		# https://github.com/python/cpython/issues/93619 (Linking error when building 3.11 beta on mips64le) + https://peps.python.org/pep-0011/ (mips is not even tier 3)
		case "$version" in
			3.9) ;;
			*) variantArches="$(sed <<<" $variantArches " -e 's/ mips64le / /g')" ;;
		esac

		sharedTags=()
		for windowsShared in windowsservercore nanoserver; do
			if [[ "$variant" == "$windowsShared"* ]]; then
				sharedTags=( "${versionAliases[@]/%/-$windowsShared}" )
				sharedTags=( "${sharedTags[@]//latest-/}" )
				break
			fi
		done
		if [ "$variant" = "$defaultDebianVariant" ] || [[ "$variant" == 'windowsservercore'* ]]; then
			sharedTags+=( "${versionAliases[@]}" )
		fi

		echo
		echo "Tags: $(join ', ' "${variantAliases[@]}")"
		if [ "${#sharedTags[@]}" -gt 0 ]; then
			echo "SharedTags: $(join ', ' "${sharedTags[@]}")"
		fi
		cat <<-EOE
			Architectures: $(join ', ' $variantArches)
			GitCommit: $commit
			Directory: $dir
		EOE
		if [[ "$v" == windows/* ]]; then
			echo "Constraints: $variant"
			echo 'Builder: classic'
		fi
	done
done
