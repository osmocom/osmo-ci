#!/bin/sh
set -e -x
WORKSPACE_DIR="$(realpath "$(dirname "$0")/..")"

# Clone repository to ~/, or update existing
# $1: name of osmocom project
clone_repo() {
	local project="$1"
	local url="https://gerrit.osmocom.org/$project"

	if [ -d ~/"$project" ]; then
		cd ~/"$project"
		git remote set-url origin "$url"
	else
		cd ~
		git clone "$url"
		cd "$project"
	fi

	git rev-parse HEAD
	git status

	git fetch && git checkout -f -B master origin/master

	git rev-parse HEAD
	git status

	cd "$WORKSPACE_DIR"
}

clone_repo osmo-ci
clone_repo osmo-gsm-manuals

if [ `uname` = "Linux" ] && [ "x${OSMO_CI_NO_DOCKER}" != "x1" ]; then
	scripts/osmo-ci-docker-rebuild.sh
fi
