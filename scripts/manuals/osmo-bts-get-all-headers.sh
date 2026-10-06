#!/bin/sh -ex

BTS_MODELS="
	sysmo
	oct
	lc15
	oc2g
"

for i in $BTS_MODELS; do
	mkdir /tmp/"$i"
	cd /tmp/"$i"
	/osmo-ci-scripts/osmo-layer1-headers.sh "$i"
done
