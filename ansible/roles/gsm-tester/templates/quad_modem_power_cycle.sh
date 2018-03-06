#!/bin/sh
set -ex
uhubctl -p 123456 -a 0
# give a lot of time to discharge capacitors on the board
sleep 20
uhubctl -p 123456 -a 1
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
