#!/bin/sh -ex
SCRIPT_DIR="$(realpath "$(dirname "$(realpath "$0")")")"
BASE_DIR="/downloads/obs-mirror/"

cd "$BASE_DIR"

rsync \
        -a \
        --list-only \
        --files-from "$SCRIPT_DIR"/obs-mirror-include.txt \
        --recursive \
        "$(realpath .previous)"/ \
        new-backup-dir/
