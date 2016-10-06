#!/bin/sh

project="$1"
branch="$2"
cfg="$3"

set -e

set +x
echo
echo
echo
echo " =============================== $project ==============================="
echo
if [ -z "$project" ]; then
	echo "internal failure: \$project is empty"
	exit 1
fi
if [ -z "$deps" ]; then
	echo "internal failure: \$deps is empty"
	exit 1
fi
if [ -z "$inst" ]; then
	echo "internal failure: \$inst is empty"
	exit 1
fi
if [ -z "$MAKE" ]; then
	echo "internal failure: \$MAKE is empty"
	exit 1
fi
set -x

mkdir -p "$deps"
cd "$deps"
rm -rf "$project"
osmo-deps.sh "$project"
cd "$project"
if [ -n "$branch" ]; then
	git checkout "$branch"
fi
git rev-parse HEAD # log current HEAD

autoreconf --install --force
./configure --prefix="$inst" $cfg
$MAKE $PARALLEL_MAKE install
