#!/bin/sh
set -ex

locations="$(uhubctl -n 1d50:4002 | grep "Current status for hub" | awk '{print $5}')"
for l in $locations; do
	uhubctl -p 123456 -a 0 -n 1d50:4002 -l $l
done
# give a lot of time to discharge capacitors on the board
sleep 20
for l in $locations; do
	uhubctl -p 123456 -a 1 -n 1d50:4002 -l $l
done
attempts=30
while [ "x$(uhubctl | grep -e 05c6 -e 1199 -c)" != "x{{ gsm_modems }}" ]; do
	attempts=$(($attempts - 1))
	if [ "$attempts" -le 0 ]; then
		echo "Timeout"
		exit 1
	fi
	sleep 1
done
uhubctl
