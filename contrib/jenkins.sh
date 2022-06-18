#!/bin/sh
set -e -x

# Clone repository to ~/, or update existing
# $1: name of osmocom project
clone_repo() {
	cd ~/"$1" || (cd ~/ && git clone https://git.osmocom.org/"$1" && cd ~/"$1")
	git rev-parse HEAD
	git status

	git fetch && git checkout -f -B master origin/master

	git rev-parse HEAD
	git status
}

clone_repo osmo-ci
clone_repo osmo-gsm-manuals

if [ `uname` = "Linux" ] && [ "x${OSMO_CI_NO_DOCKER}" != "x1" ]; then
	cd ~/osmo-ci
	scripts/osmo-ci-docker-rebuild.sh
fi
