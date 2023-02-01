#!/bin/sh -ex
# Use this script for local testing of the prepare source and build scripts
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

export SRC_SKIP_FETCH=1
export SRC_CLEAN=1

mkdir -p /tmp/coverity
rm -f /tmp/coverity/common.sh
cp "$SCRIPT_DIR"/* /tmp/coverity
ln -sf "$SCRIPT_DIR/../scripts/common.sh" /tmp/coverity/common.sh

cd /tmp/coverity

./prepare_source_Osmocom.sh
./build_Osmocom.sh
