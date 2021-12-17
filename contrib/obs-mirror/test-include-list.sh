#!/bin/sh -ex
BASE_DIR="/downloads/obs-mirror/"

cd "$BASE_DIR"

rsync \
        -a \
        --list-only \
        --files-from /home/pkgmirror/obs-mirror-include.txt \
        --recursive \
        "$(realpath .previous)"/ \
        new-backup-dir/
