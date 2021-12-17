#!/bin/sh -e
# Remove nightly archives older than one month (OS#4862)
DRY=0

# Get removal date in seconds since epoch and display it
DATE_RM_SEC=$(expr $(date +%s) - 3600 \* 24 \* 32)
DATE_RM_STR=$(date -d "@$DATE_RM_SEC" +"%Y-%m-%d")
echo "Removing nightly archives from $DATE_RM_STR and older"

cd /downloads/obs-mirror

for i in */nightly; do
        # "Last modified" isn't set to the date of the dir name for some
        # archives, so parse the date from the dir name instead
        DATE_DIR="$(basename "$(dirname "$i")")"  # e.g. "20210604-002301"
        DATE_DIR_SEC="$(date -d "$(echo "$DATE_DIR" | cut -d "-" -f 1)" +%s)"
        if [ -z "$DATE_DIR_SEC" ]; then
                echo "ERROR: $i: failed to parse date from dir name"
                continue
        fi

        if [ "$DATE_DIR_SEC" -lt "$DATE_RM_SEC" ]; then
                DATE_DIR_STR="$(date -d "@$DATE_DIR_SEC" +"%Y-%m-%d")"
                echo "Removing $i ($DATE_DIR_STR)..."
                if [ "$DRY" = 0 ]; then
                        rm -r "$i"
                fi
        fi
done

echo "Done"
