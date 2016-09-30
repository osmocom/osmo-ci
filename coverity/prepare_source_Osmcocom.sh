#!/bin/sh
mkdir -p source-Osmocom

cd source-Osmocom

for proj in \
  asn1c \
  libasn1c \
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
  osmo-iuh \
  osmo-pcu \
  osmo-sip-connector \
  ; do

  git clone git://git.osmocom.org/$proj
done

git clone git://git.sysmocom.de/sysmo-bts/layer1-api

git -C asn1c checkout aper-prefix
git -C libosmo-netif checkout sysmocom/sctp
git -C libosmo-sccp checkout sysmocom/iu
git -C openbsc checkout sysmocom/iu
