#!/bin/sh
set -e -x

cd ~/osmo-ci || (cd ~/ && git clone git://git.osmocom.org/osmo-ci && cd ~/osmo-ci)
git rev-parse HEAD
git status

git fetch && git checkout -f -B master origin/master

git rev-parse HEAD
git status

if [ `uname` = "Linux" ] && [ "x${OSMO_CI_NO_DOCKER}" != "x1" ]; then
	scripts/osmo-ci-docker-rebuild.sh
fi
