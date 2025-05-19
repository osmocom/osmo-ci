#!/bin/sh -e
SCRIPTS_OBS_DIR="$(realpath "$(dirname "$0")")"
DISTRO="$1"
FEED=${2:-master}

error_exit() {
	echo "---"
	echo "NOTE: if the build failed because dependencies are outdated, see the status here:"
	echo "https://obs.osmocom.org/project/show/osmocom:master"
	echo "---"
	exit 1
}


if [ -z "$DISTRO" ]; then
	echo "usage: gerrit-binpkgs.sh DISTRO [FEED]"
	echo
	echo "FEED defaults to master."
	echo
	echo "examples:"
	echo "  gerrit-binpkgs.sh debian:12"
	echo "  gerrit-binpkgs.sh ubuntu:24.04 nightly"
	echo "  gerrit-binpkgs.sh almalinux:8"
	exit 1
fi

GIT_REPO_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$GIT_REPO_DIR" ]; then
	echo "ERROR: run inside a git repository of an Osmocom project"
	exit 1
fi

CACHE_DIR="$SCRIPTS_OBS_DIR/_cache"
PROJECT_NAME="$(basename "$GIT_REPO_DIR")"

# Copy the source dir into the cache dir. It will be mounted inside the docker
# containers for building source and binary packages (so using a symlink does
# not work). Use rsync so it is very fast.
echo ":: Copying the source to the cache dir"
mkdir -p "$CACHE_DIR"
rsync -a --delete "$GIT_REPO_DIR" "$CACHE_DIR"

# --feed must be master here, as for build_srcpkg it means that we take the
# currently checked out commit and add a commit_….txt file.
echo ":: Building the source package"
"$SCRIPTS_OBS_DIR"/build_srcpkg.py \
	--allow-unknown-package \
	--docker \
	--feed master \
	--git-skip-fetch \
	--git-skip-checkout \
	--no-meta \
	"$PROJECT_NAME" || error_exit

echo ":: Building the binary packages"
"$SCRIPTS_OBS_DIR"/build_binpkg.py \
	--docker "$DISTRO" \
	--feed "$FEED" \
	"$PROJECT_NAME" || error_exit

echo ":: Find binary packages in: $SCRIPTS_OBS_DIR/_temp/binpkgs"
