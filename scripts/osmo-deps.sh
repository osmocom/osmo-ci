#!/bin/sh
. "$(dirname "$0")/common.sh"
set -ex
project="$1"
branch="${2:-master}"
# If ref is really a branch, we want to track the remote one:
if [ "x$(git branch -a | grep -c "remotes/origin/$branch\$")" != "x0" ]; then
        branch="origin/$branch"
fi


if ! test -d "$project"; then
	git clone "$(osmo_git_clone_url "$project")" "$project"
fi

cd "$project"
git fetch --tags origin
git fetch origin

# Cleanup should already have happened during a global osmo-clean-workspace.sh,
# but in case the caller did not (want to) call that, let's also do cleanup in
# this dep subdir separately, making sure to not pass in $deps as abspath.
deps="" osmo-clean-workspace.sh

git checkout -f "$branch"
git rev-parse HEAD
