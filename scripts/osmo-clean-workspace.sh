#!/bin/sh
# Clean workspace.
# This should be the first and last step of every jenkins build:
# a) to make sure the workspace has no build artifacts from previous runs.
# b) to reduce disk space lost to unused binaries; parallel and/or matrix
#    builds create numerous workspaces, blowing up disk usage.
# Note that if a build fails, the last steps will not run, hence calling this
# as last step cleans only in case there was no build failure, i.e. where we
# don't need to keep anything anyway.
#
# Assume $PWD is a git clone's root dir. Usually, that's also the jenkins
# workspace root. Do not wipe subdir 'layer1-headers' as well as all dirs under
# '$deps'. These are assumed to be git clones that do not need to be re-cloned
# every time. Do a 'git clean' in each of them individually. If '$deps' is not
# defined or the mentioned dirs do not exist, nothing special happens, so this
# script can be safely run in any git clone in deeper subdirs of the workspace.

set -ex

# make sure no write protected cruft is in the way. A failed 'make distcheck'
# has a habit of leaving a non-writable dir tree behind.
chmod -R +w .

# wipe all local modifications
git checkout -f HEAD

# wipe all unversioned leftovers, except deps gits.
git clean -dxf -e "$deps" -e "layer1-headers"

# leave the deps checkouts around, to not clone entire git history every time,
# but clean each git of build artifacts.
if [ -d "$deps" ]; then
  for dep_dir in "$deps"/* ; do
    git checkout -f HEAD
    git -C "$dep_dir" clean -dxf
  done
fi

if [ -d "layer1-headers" ]; then
  git checkout -f HEAD
  git -C "layer1-headers" clean -dxf
fi
