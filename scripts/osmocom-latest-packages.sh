#!/bin/sh

# requirements
# apt install git-buildpackage osc git

set -e
set -x

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
  gitbpargs=""
  echo
  echo "====> Building $project"
  cd "$TOP"
  if [ "$project" = "limesuite" ]; then
     ver_regexp="^v[0-9]*.[0-9]*.[0-9]*$"
     [ -d "$project" ] || git clone "https://github.com/myriadrf/LimeSuite" "$project"
  else
    ver_regexp="^[0-9]*.[0-9]*.[0-9]*$"
    [ -d "$project" ] || git clone "git://git.osmocom.org/$project"
  fi
  cd "$project"
  git fetch
  VER=$(git tag -l --sort=v:refname | grep "$ver_regexp" | tail -n 1)
  if [ "$project" = "limesuite" ]; then
    gitbpargs="--git-upstream-tree=$VER"
  fi
  git checkout -f -B "$VER" "refs/tags/$VER"
  if [ -x ./git-version-gen ]; then
    ./git-version-gen . > .tarball-version 2>/dev/null
    gbp buildpackage -S -uc -us -d --git-ignore-branch "--git-export-dir=$output" \
		     "--git-debian-branch=$VER" --git-ignore-new $gitbpargs \
		     --git-postexport='cp $GBP_GIT_DIR/../.tarball-version $GBP_TMP_DIR/'
  else
    gbp buildpackage -S -uc -us -d --git-ignore-branch "--git-export-dir=$output" \
		     "--git-debian-branch=$VER" --git-ignore-new $gitbpargs
  fi

  if [ ! -d "$TOP/$PROJ/$project" ] ; then
    # creating a new package is different from using old ones
    mkdir "$TOP/$PROJ/$project"
    mv "$output/"*.dsc "$TOP/$PROJ/$project/"
    mv "$output/"*.tar* "$TOP/$PROJ/$project/"
    cd "$TOP/$PROJ"
    osc add "$project"
  else
    cd "$TOP/$PROJ/$project"

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

# add those two once they have tagged any versions that include the 'debian' sub-dir
	#rtl-sdr
	#osmo-fl2k

[ -d "$TOP/debsrc" ] && rm -rf "$TOP/debsrc"
mkdir "$TOP/debsrc"

build_debsrc() {
  build "$1" "$TOP/debsrc/$1"
}

build_debsrc limesuite
build_debsrc libosmocore
#build_debsrc libosmo-sccp
#build_debsrc libosmo-abis
#build_debsrc libosmo-netif
#build_debsrc libsmpp34
#build_debsrc libasn1c
#build_debsrc libgtpnl
#build_debsrc libusrp
#build_debsrc osmo-iuh
#build_debsrc osmo-ggsn
#build_debsrc osmo-sgsn
#build_debsrc openbsc
#build_debsrc osmo-pcap
build_debsrc osmo-trx
#build_debsrc osmo-sip-connector
#build_debsrc osmo-bts
#build_debsrc osmo-pcu
#build_debsrc osmo-hlr
#build_debsrc osmo-mgw
#build_debsrc osmo-msc
#build_debsrc osmo-bsc
#build_debsrc simtrace2

cd "$TOP/$PROJ"
osc ci -m "Latest Tagged versions of $DT"
