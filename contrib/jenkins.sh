#!/bin/sh
set -e -x

cd ~/osmo-ci || (cd ~/ && git clone git://git.osmocom.org/osmo-ci && cd ~/osmo-ci)
git rev-parse HEAD
git status

git pull origin

git rev-parse HEAD
git status

if [ `uname` = "Linux" ]; then
 cd docker
 ./rebuild_osmocom_jenkins_image.sh
fi
