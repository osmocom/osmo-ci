#!/bin/sh
BASEDIR=source-Osmocom

[ -d $BASEDIR ] || mkdir -p $BASEDIR
cd $BASEDIR

for proj in \
  asn1c \
  libasn1c \
  libosmo-abis \
  libosmocore \
  libosmo-dsp \
  libosmo-netif \
  libosmo-sccp \
  libsmpp34 \
  libusrp \
  osmo-bsc \
  osmo-msc \
  osmo-mgw \
  osmo-ggsn \
  osmo-gbproxy \
  osmo-sgsn \
  osmo-bts \
  osmo-gmr \
  osmo-iuh \
  osmo-pcu \
  osmo-sysmon \
  osmo-sip-connector \
  osmo-trx \
  osmo-hlr \
  osmocom-bb \
  osmo-smlc \
  osmo-cbc \
  simtrace2 \
  ; do

	if [ -d $proj ]; then
		(cd $proj && git fetch && git checkout -f -B master origin/master)
	else
		git clone git://git.osmocom.org/$proj
	fi
done

git clone https://git.sysmocom.de/sysmo-bts/layer1-api
