#!/bin/sh -e
# SYS#8011
TMP_DIR=/tmp/osmo-ccid-firmware-tests
CAPTURE_BUS_ID="$(lsusb | grep sysmoOCTSIM | cut -d ' ' -f 2 | tr -d 0)"

if [ -e "$TMP_DIR"/dumpcap.pid ]; then
	kill -9 $(cat "$TMP_DIR"/dumpcap.pid) || true
fi

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"/logs

cd "$TMP_DIR"

# Store current date, so stop-hook.sh can get pcscd logs from journalctl
date "+%F %H:%M:%S" >start_date

echo "[start-hook] restarting pcscd"
sleep 1
systemctl restart pcscd
sleep 1

# usbmon capture
if [ -n "$CAPTURE_BUS_ID" ]; then
	echo "[start-hook] starting usbmon capture on bus $CAPTURE_BUS_ID"
	modprobe usbmon
	timeout 1h \
		dumpcap \
		-i usbmon"$CAPTURE_BUS_ID" \
		-w logs/usbmon.pcapng \
		>logs/dumpcap.log 2>&1 &
	echo "$!" >dumpcap.pid
else
	echo "[start-hook] warning: failed to get capture bus ID, skipping capture"
fi

echo "[start-hook] done"
