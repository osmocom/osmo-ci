#!/bin/sh -e
# SYS#8011
OUTPUT_DIR="$PWD"
TMP_DIR=/tmp/osmo-ccid-firmware-tests
START_DATE=$(cat "$TMP_DIR"/start_date)

if ! [ -d "$TMP_DIR" ]; then
	echo "[stop-hook] nothing to do"
	exit 0
fi

cd "$TMP_DIR"

show_size() {
	printf "[stop-hook]   "
	du -h "$1"
}

# Store pcscd log
echo "[stop-hook] getting pcscd logs since $START_DATE"
journalctl \
	-u pcscd.service \
	--since="$START_DATE" \
	>logs/pcscd.log
show_size logs/pcscd.log

echo "[stop-hook] stopping usbmon capture"
kill -9 $(cat dumpcap.pid) || true
rm dumpcap.pid
show_size logs/usbmon.pcapng

echo "[stop-hook] compressing usbmon capture"
pigz logs/usbmon.pcapng
show_size logs/usbmon.pcapng.gz

chown -R jenkins:jenkins logs
cd "$OUTPUT_DIR"
mv "$TMP_DIR"/logs .
rm -rf "$TMP_DIR"

echo "[stop-hook] done"
