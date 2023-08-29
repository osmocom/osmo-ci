#!/bin/sh -ex
# Used by jobs/master-builds.yml for xgoldmon
TOPDIR=/build

if ! [ -x "$(command -v osmo-build-dep.sh)" ]; then
	echo "Error: missing scripts from osmo-ci.git in PATH!"
	exit 2
fi

set -x

osmo-clean-workspace.sh

export deps="$TOPDIR/deps"
export inst="$deps/install"
export PKG_CONFIG_PATH="$inst/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="$inst/lib"

mkdir -p deps
osmo-build-dep.sh libosmocore "" '--disable-doxygen'

cd "$TOPDIR"
$MAKE
