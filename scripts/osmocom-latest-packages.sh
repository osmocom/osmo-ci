#!/bin/sh

# requirements
# apt install git-buildpackage osc git

set -e

# OBS project name
PROJ=network:osmocom:latest

DT=$(date +%Y%m%d)
TOP=$(pwd)

if ! which osc >/dev/null 2>/dev/null ; then
  echo "osc binary not found"
  exit 1
fi

# start with a checkout of the project
if [ -d $PROJ ]; then
	(cd $PROJ && osc up)
else
	osc co $PROJ
fi

build() {
  project=$1
  output=$2
  echo
  echo "====> Building $project"
  cd "$TOP"
  [ -d "$1" ] || git clone "git://git.osmocom.org/$1"
  cd "$1"
  git fetch
  VER=$(git describe --abbrev=0 --tags --match "*.*.*" origin/master)
  git checkout -f -B "$VER" "refs/tags/$VER"
  gbp buildpackage -d -S -uc -us "--git-export-dir=$output" "--git-debian-branch=$VER"

  if [ ! -d "$TOP/$PROJ/$1" ] ; then
    # creating a new package is different from using old ones
    mkdir "$TOP/$PROJ/$1"
    mv "$output/"*.dsc "$TOP/$PROJ/$1/"
    cd "$TOP/$PROJ"
    osc add "$1"
  else
    cd "$TOP/$PROJ/$1"

    # update OBS only if the filename doesn't match
    file=$(cd "$output/" ; ls ./*.dsc)
    if [ ! -e "$file" ] ; then
      osc rm ./* || true
      mv "$output/"*.dsc .
      mv "$output/"*.tar* .
        osc add ./*
      fi
  fi
  cd "$TOP"
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

[ -d "$TOP/debsrc" ] && rm -rf "$TOP/debsrc"
mkdir "$TOP/debsrc"

for p in $PACKAGES; do
	build "$p" "$TOP/debsrc/$p"
done

cd "$TOP/$PROJ"
osc ci -m "Latest Tagged versions of $DT"
