#!/bin/sh -ex
min=10
max=500
wget -q https://obs.osmocom.org -O index.html

set +x
for i in $(seq $min $max); do
	if grep -q " of $i build hosts" index.html; then
		echo
		echo "Check successful, $i builders are connected to OBS"
		echo
		exit 0
	fi
done

echo
echo "ERROR: expected at least $min builders to be connected to OBS!"
echo
exit 1
