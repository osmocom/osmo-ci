#!/bin/sh
set -ex
project="$1"
branch="${2:-origin/master}"

if ! test -d "$project";
then
  git clone "git://git.osmocom.org/$project" "$project"
fi

cd "$project"
git fetch origin

# Cleanup should already have happened during a global osmo-clean-workspace.sh,
# but in case the caller did not (want to) call that, let's also do cleanup in
# the dep subdir separately:
osmo-clean-workspace.sh

git checkout -f "$branch"
git rev-parse HEAD
