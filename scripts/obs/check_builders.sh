#!/bin/sh -ex
count=14
wget -q https://obs.osmocom.org -O index.html

if ! grep -q " of $count build hosts" index.html; then
	grep "build hosts" index.html
	set +x
	echo
	echo "ERROR: expected $count builders to be connected to OBS!"
	echo
fi