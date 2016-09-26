#!/bin/sh
mkdir -p source

cd source

for proj in \
  libosmo-abis \
  libosmocore \
  libosmo-dsp \
  libosmo-netif \
  libosmo-sccp \
  libsmpp34 \
  openbsc \
  openggsn \
  osmo-bts \
  osmo-gmr \
  osmo-pcu \
  osmo-trx \
  ; do

  git clone git://git.osmocom.org/$proj
done

git clone git://git.sysmocom.de/sysmo-bts/layer1-api
