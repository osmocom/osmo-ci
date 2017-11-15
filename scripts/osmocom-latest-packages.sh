#!/bin/sh

set -e

# OBS project name
PROJ=network:osmocom:latest

DT=`date +%Y%m%d`
TOP=$(pwd)

# start with a checkout of the project
if [ -d $PROJ ]; then
	(cd $PROJ && osc up)
else
	osc co $PROJ
fi

build() {
  echo
  echo "====> Building $1"
  cd $TOP
  rm -rf data
  [ -d $1 ] || git clone git://git.osmocom.org/$1
  cd $1
  git fetch
  VER=`git describe --abbrev=0 --tags --match "*.*.*" origin/master`
  git checkout -f -B $VER refs/tags/$VER
  gbp buildpackage -d -S -uc -us --git-export-dir=$TOP/data --git-debian-branch=$VER
  cd $TOP/$PROJ/$1
  osc rm * || true
  mv $TOP/data/*.dsc .
  mv $TOP/data/*.tar* .
  osc add *
  cd $TOP
}

PACKAGES="
	libosmocore
	libosmo-sccp
	libosmo-abis
	libosmo-netif
	libsmpp34
	libasn1c
	osmo-iuh
	osmo-ggsn
	osmo-sgsn
	openbsc
	osmo-pcap
	osmo-trx
	osmo-sip-connector
	osmo-bts
	osmo-pcu
	osmo-hlr
	osmo-mgw
	osmo-msc
	osmo-bsc
	"

for p in $PACKAGES; do
	build $p
done

cd $TOP/$PROJ
osc ci -m "Latest Tagged versions of $DT"
