#!/bin/sh -ex
SCRIPTS_DIR="$(realpath "$(dirname "$0")/..")"

BTS_MODELS="
	sysmo
	oct
	lc15
	oc2g
"

for i in $BTS_MODELS; do
	DIR=/tmp/osmo-layer1-headers/"$i"

	if [ -f "$DIR/.done" ]; then
		continue
	fi

	mkdir -p "$DIR"
	cd "$DIR"
	"$SCRIPTS_DIR"/osmo-layer1-headers.sh "$i"
	touch "$DIR"/.done
done

# Create the directory structure expected for the sysmocom/femtobts headers:
# https://gitea.osmocom.org/cellular-infrastructure/osmo-bts/src/branch/master/contrib/jenkins_sysmobts.sh
cd /tmp/osmo-layer1-headers/sysmo/
if ! [ -e .done-inst ]; then
	mkdir -p inst/include/sysmocom/femtobts
	ln -s /tmp/osmo-layer1-headers/sysmo/layer1-headers/include/* \
		inst/include/sysmocom/femtobts/
	touch .done-inst
fi
