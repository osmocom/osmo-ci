#!/bin/bash

# Mirror script to create a local archive of the OBS packages in the network:osmocom
# repositories / projects
#
# We are using hard-links to perform de-duplication on the local side; only
# those files that changed compoared to the previous run will be rsync'ed over
# from the remote side
#
# See also: OS#4862

DATE=`date +%Y%m%d-%H%M%S`
LOGFILE="/home/pkgmirror/obs-mirror-$DATE.log"
echo "Redirecting all output to: $LOGFILE"
exec >$LOGFILE 2>&1

set -e -x
SCRIPT_DIR="$(realpath "$(dirname "$(realpath "$0")")")"

# base directory on the local side
BASE_DIR="/downloads/obs-mirror/"
# sync remote where to find the osmocom packages
REMOTE="downloads.osmocom.org::packages/osmocom:"

cd "$BASE_DIR"

RSYNC_ARGS="-av --delete"
RSYNC_ARGS="$RSYNC_ARGS --files-from $SCRIPT_DIR/obs-mirror-include.txt --recursive --exclude='.*'"
DIR="$BASE_DIR/$DATE"
TEMP_DIR="$BASE_DIR/.temp"

rm -rf "$TEMP_DIR"
mkdir "$TEMP_DIR"

PREVIOUS="$BASE_DIR/.previous"
if [ -d "$PREVIOUS" ]; then
	RSYNC_ARGS+=" --link-dest=$PREVIOUS"
fi

# finally, perform rsync
if rsync $RSYNC_ARGS "$REMOTE"/ "$TEMP_DIR"/; then
	mv "$TEMP_DIR" "$DIR"

	# update '.previous' for the next run
	rm -f "$PREVIOUS"
	ln -sf "$DATE" "$PREVIOUS"
else
	exit 1
fi
