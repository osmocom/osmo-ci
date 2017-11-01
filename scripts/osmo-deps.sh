#!/bin/sh
set -ex
project="$1"
branch="origin/${2:-master}"

if ! test -d "$project";
then
  git clone "git://git.osmocom.org/$project" "$project"
fi

cd "$project"
git fetch origin

# Cleanup should already have happened during a global osmo-clean-workspace.sh,
# but in case the caller did not (want to) call that, let's also do cleanup in
# this dep subdir separately, making sure to not pass in $deps as abspath.
deps="" osmo-clean-workspace.sh

git checkout -f "$branch"
git rev-parse HEAD
