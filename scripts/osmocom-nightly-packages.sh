#!/bin/sh

# rather than including a dangerous 'rm -rf *' here, lets delegate to the user:
if [ -n "$(ls)" ]; then
  echo "ERROR: I need to run in an empty directory."
  exit 1
fi

set -x -e

git clone git://git.osmocom.org/osmo-sip-connector
git clone git://git.osmocom.org/libosmocore
git clone git://git.osmocom.org/libosmo-sccp
git clone git://git.osmocom.org/libosmo-abis
git clone git://git.osmocom.org/libosmo-netif
git clone git://git.osmocom.org/libsmpp34
git clone git://git.osmocom.org/osmo-iuh
git clone git://git.osmocom.org/osmo-sgsn
git clone git://git.osmocom.org/osmo-ggsn
git clone git://git.osmocom.org/openbsc
git clone git://git.osmocom.org/osmo-pcap
git clone git://git.osmocom.org/cellmgr-ng osmo-stp
git clone git://git.osmocom.org/osmo-trx
git clone git://git.osmocom.org/osmo-bts
git clone git://git.osmocom.org/osmo-pcu
git clone git://git.osmocom.org/osmo-hlr


PROJ=network:osmocom:nightly
osc co $PROJ

DT=`date +%Y%m%d`


build() {
  rm -rf data
  cd $1
  VER=`head -1 debian/changelog | cut -d ' ' -f 2 | sed s,"(","",  | sed s,")","",`
  dch -v $VER.$DT -m "Snapshot build"
  git commit -m "$DT snapshot" debian/
  gbp buildpackage -S -uc -us --git-export-dir=$PWD/../data
  cd ../$PROJ/$1
  osc rm * || true
  mv ../../data/*.dsc .
  mv ../../data/*.tar* .
  osc add *
  cd ../../
}

build libosmocore
build libosmo-sccp
build libosmo-abis
build libosmo-netif
build libsmpp34
build osmo-iuh
build osmo-ggsn
build osmo-sgsn
build openbsc
build osmo-pcap
build osmo-stp
build osmo-trx
build osmo-sip-connector

cp openbsc/openbsc/include/openbsc/gsm_data_shared.h osmo-bts/include/openbsc/
cp openbsc/openbsc/src/libcommon/gsm_data_shared.c osmo-bts/src/common/gsm_data_shared.c
cd osmo-bts
git add include/openbsc/gsm_data_shared.h
git add src/common/gsm_data_shared.c
git commit -m "Copy OpenBSC files needed for the build"
cd ../
build osmo-bts
build osmo-pcu
build osmo-hlr

cd $PROJ
osc ci -m "Snapshot $DT"
