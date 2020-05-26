#!/bin/sh -e
# Iterate over all relevant Osmocom repositories and generate release tarballs for each of the repository tags. The tags
# are queried from the git server without cloning the repositories first, so we can clone them only if we need to build
# a missing tarball. All repositories are deleted afterwards to save space.
#
# Environment variables:
# * KEEP_TEMP: do not delete cloned repositories (use for development)
# * PARALLEL_MAKE: -jN argument for make (default: -j5).

. "$(dirname "$0")/common.sh"
cd "$(dirname "$0")"
PARALLEL_MAKE="${PARALLEL_MAKE:--j5}"
OUTPUT="$(cd ..; pwd)/_release_tarballs"
TEMP="$(cd ..; pwd)/_temp"

# Print all tags for which no release tarball should be built.
# $1: Osmocom repository
tags_to_ignore() {
	case "$1" in
		libosmocore)
			# configure.ac:144: error: required file 'src/gb/Makefile.in' not found
			echo "0.5.0"
			echo "0.5.1"
			;;
		libsmpp34)
			# duplicate of 1.12.0
			echo "1.12"
			;;
		osmo-bsc)
			# openbsc
			echo "1.0.1"
			# Requires libosmo-legacy-mgcp
			echo "1.1.0"
			echo "1.1.1"
			echo "1.1.2"
			echo "1.2.0"
			echo "1.2.1"
			echo "1.2.2"
			;;
		osmo-bts)
			# gsm_data_shared.h:464:26: error: field 'power_params' has incomplete type
			echo "0.2.0"
			echo "0.3.0"
			;;
		osmo-hlr)
			# Not using autotools
			echo "0.0.1"
			;;
		osmo-mgw)
			# openbsc
			echo "1.0.1"
			;;
		osmo-msc)
			# openbsc
			echo "1.0.1"
			;;
		osmo-pcu)
			# Duplicates of 0.1.0, 0.2.0
			echo "0.1"
			echo "0.2"
			;;
		osmo-sgsn)
			# openbsc
			echo "0.9.0 0.9.1 0.9.2 0.9.3 0.9.4 0.9.5 0.9.6 0.9.8 0.9.9 0.9.10 0.9.11 0.9.12 0.9.13 0.9.14"
			echo "0.9.15 0.9.16 0.10.0 0.10.1 0.11.0 0.12.0 0.13.0 0.14.0 0.15.0 1.0.1"
			;;
		osmo-sip-connector)
			# make: *** No rule to make target 'osmoappdesc.py'
			echo "0.0.1"
			;;
		osmo-trx)
			# cp: cannot stat './/home/user/code/osmo-dev/src/osmo-ci/_temp/repos/osmo-trx/configure'
			echo "0.2.0"
			echo "0.3.0"
			;;
	esac
}

# Clone dependency repositories.
# $1: Osmocom repository
prepare_depends() {
	case "$1" in
		osmo-bts)
			# Includes openbsc/gsm_data_shared.h
			prepare_repo "openbsc"
			;;
	esac
}

# Apply workarounds for bugs that break too many releases. This function runs between ./configure and make dist-bzip2.
# $1: Osmocom repository
fix_repo() {
	case "$1" in
		osmo-mgw)
			# No rule to make target 'osmocom/mgcp_client/mgcp_common.h' (OS#4084)
			make -C "$TEMP/repos/$1/include/osmocom/mgcp_client" mgcp_common.h || true
			;;
	esac
}

# Check if one specific tag should be ignored.
# $1: Osmocom repository
# $2: tag (e.g. "1.0.0")
ignore_tag() {
	local repo="$1"
	local tag="$2"
	local tags="$(tags_to_ignore "$repo")"
	for tag_i in $tags; do
		if [ "$tag" = "$tag_i" ]; then
			return 0
		fi
	done
	return 1
}

# Delete existing temp dir (unless KEEP_TEMP is set). If all repos were checked out, this restores ~500 MB of space.
remove_temp_dir() {
	if [ -n "$KEEP_TEMP" ]; then
		echo "NOTE: not removing temp dir, because KEEP_TEMP is set: $TEMP"
	elif [ -d "$TEMP" ]; then
		rm -rf "$TEMP"
	fi
}

# Clone an Osmocom repository to $TEMP/repos/$repo, clean it, checkout a tag.
# $1: Osmocom repository
# $2: tag (optional, default: master)
prepare_repo() {
	local repo="$1"
	local tag="${2:-master}"

	if ! [ -d "$TEMP/repos/$repo" ]; then
		git -C "$TEMP/repos" clone "$OSMO_GIT_URL/$repo"
	fi

	cd "$TEMP/repos/$repo"
	git clean -qdxf
	git reset --hard HEAD # in case the tracked files were modified (e.g. libsmpp34 1.10)
	git checkout -q "$tag"
}

# Checkout a given tag and build a release tarball.
# $1: Osmocom repository
# $2: tag
create_tarball() {
	local repo="$1"
	local tag="$2"
	local tarball="$repo-$tag.tar.bz2"

	# Be verbose during the tarball build and preparation. Everything else is not verbose, so we can generate an
	# easy to read overview of tarballs that are already built or are ignored.
	set -x

	prepare_repo "$repo" "$tag"
	prepare_depends "$repo"

	cd "$TEMP/repos/$repo"
	autoreconf -fi
	./configure
	fix_repo "$repo"
	make dist-bzip2

	# Back to non-verbose mode
	set +x

	if ! [ -e "$tarball" ]; then
		echo "NOTE: tarball has a different name (wrong version in configure.ac?), renaming."
		mv -v *.tar.bz2 "$tarball"
	fi
}

# Move a generated release tarball to the output dir.
move_tarball() {
	local repo="$1"
	local tag="$2"
	local tarball="$repo-$tag.tar.bz2"

	cd "$TEMP/repos/$repo"
	mkdir -p "$OUTPUT/$repo"
	mv "$tarball" "$OUTPUT/$repo/$tarball"
}

remove_temp_dir
mkdir -p "$TEMP/repos"
echo "Temp dir: $TEMP"

for repo in $OSMO_RELEASE_REPOS; do
	echo "$repo"
	tags="$(osmo_git_last_commits_tags "$repo" "all" | cut -d / -f 3)"

	# Skip untagged repos
	if [ -z "$tags" ]; then
		echo "  (repository has no release tags)"
		continue
	fi

	# Build missing tarballs for each tag
	for tag in $tags; do
		tarball="$repo-$tag.tar.bz2"
		if ignore_tag "$repo" "$tag"; then
			echo "  $tarball (ignored)"
			continue
		elif [ -e "$OUTPUT/$repo/$tarball" ]; then
			echo "  $tarball (exists)"
			continue
		fi

		echo "  $tarball (creating)"
		create_tarball "$repo" "$tag"
		move_tarball "$repo" "$tag"
	done
done

remove_temp_dir
echo "done!"
