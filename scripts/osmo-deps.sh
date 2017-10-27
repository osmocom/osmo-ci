#!/bin/sh
set -ex

if ! test -d $1;
then
  git clone git://git.osmocom.org/$1 $1
fi

cd $1
git fetch origin

# Cleanup should already have happened during a global osmo-clean-workspace.sh,
# but in case the caller did not (want to) call that, let's also do cleanup in
# the dep subdir separately:
osmo-clean-workspace.sh

git reset --hard origin/master
git rev-parse HEAD
