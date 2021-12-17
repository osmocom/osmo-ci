#!/bin/bash

# Mirror script to create a local archive of the OBS packages in the network:osmocom
# repositories / projects
#
# We are using hard-links to perform de-duplication on the local side; only
# those files that changed compoared to the previous run will be rsync'ed over
# from the remote side
#
# See also: OS#4862

set -e -x

# base directory on the local side
BASE_DIR="/downloads/obs-mirror/"
# sync remote where to find the osmocom packages
REMOTE="rsync.opensuse.org::opensuse-full-really-everything-including-repositories/opensuse/repositories/network:/osmocom:"

cd "$BASE_DIR"

RSYNC_ARGS="-av --delete"
RSYNC_ARGS="$RSYNC_ARGS --files-from /home/pkgmirror/obs-mirror-include.txt --recursive"
DATE=`date +%Y%m%d-%H%M%S`

# create output directory
DIR="$BASE_DIR/$DATE"
mkdir -p "$DIR"

PREVIOUS="$BASE_DIR/.previous"
if [ -d "$PREVIOUS" ]; then
	RSYNC_ARGS+=" --link-dest=$PREVIOUS"
fi

# finally, perform rsync
# || true: don't stop here if one of the dirs from the include list does not exist
rsync $RSYNC_ARGS "$REMOTE"/ "$DIR"/ || true

# update '.previous' for the next run
rm -f "$PREVIOUS"
ln -sf "$DATE" "$PREVIOUS"
