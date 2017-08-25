#!/bin/sh

set -e

cd ~/osmo-ci || (cd ~/ && git clone git://git.osmocom.org/osmo-ci && cd osmo-ci)
git rev-parse HEAD
git status

git fetch && git checkout -f -B master origin/master

git rev-parse HEAD
git status
