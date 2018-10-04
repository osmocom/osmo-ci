#!/bin/sh

# requirements
# apt install git-buildpackage osc git

set -e
set -x

# OBS project name
PROJ=network:osmocom:latest

DT=$(date +%Y%m%d)
TOP=$(pwd)
DEBSRCDIR="$TOP/debsrc"

if ! which osc >/dev/null 2>/dev/null ; then
  echo "osc binary not found"
  exit 1
fi

prepare() {
  # start with a checkout of the project
  if [ -d $PROJ ]; then
    (cd $PROJ && osc up)
  else
    osc co $PROJ
  fi
  [ -d "$DEBSRCDIR" ] && rm -rf "$DEBSRCDIR"
  mkdir "$DEBSRCDIR"
}

get_last_tag() {
  project="$1"
  if [ "$project" = "limesuite" ]; then
    ver_regexp="^v[0-9]*.[0-9]*.[0-9]*$"
  else
    ver_regexp="^[0-9]*.[0-9]*.[0-9]*$"
  fi
  VER=$(git -C "${TOP}/${project}" tag -l --sort=v:refname | grep "$ver_regexp" | tail -n 1)
  echo "${VER}"
}

checkout() {
  project=$1
  gitbpargs=""
  echo
  echo "====> Checking out $project"
  cd "$TOP"
  if [ "$project" = "limesuite" ]; then
     [ -d "$project" ] || git clone "https://github.com/myriadrf/LimeSuite" "$project"
  else
    [ -d "$project" ] || git clone "git://git.osmocom.org/$project"
  fi
  cd "$project"
  git fetch
  VER=$(get_last_tag "$project")
  git checkout -f -B "$VER" "refs/tags/$VER"
}

build() {
  project=$1
  gitbpargs="$2"
  output="$DEBSRCDIR/$project"
  echo
  echo "====> Building $project"
  cd "$TOP/$project"
  VER=$(get_last_tag "$project")
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

# add those two once they have tagged any versions that include the 'debian' sub-dir:
#rtl-sdr
#osmo-fl2k

build_osmocom() {
  prepare

  checkout limesuite
  checkout libosmocore
  checkout libosmo-sccp
  checkout libosmo-abis
  checkout libosmo-netif
  checkout libsmpp34
  checkout libasn1c
  checkout libgtpnl
  checkout libusrp
  checkout osmo-iuh
  checkout osmo-ggsn
  checkout osmo-sgsn
  checkout openbsc
  checkout osmo-pcap
  checkout osmo-trx
  checkout osmo-sip-connector
  checkout osmo-bts
  checkout osmo-pcu
  checkout osmo-hlr
  checkout osmo-mgw
  checkout osmo-msc
  checkout osmo-bsc
  checkout simtrace2

  build limesuite --git-upstream-tree="$(get_last_tag limesuite)"
  build libosmocore
  build libosmo-sccp
  build libosmo-abis
  build libosmo-netif
  build libsmpp34
  build libasn1c
  build libgtpnl
  build libusrp
  build osmo-iuh
  build osmo-ggsn
  build osmo-sgsn
  build openbsc
  build osmo-pcap
  build osmo-trx
  build osmo-sip-connector
  build osmo-bts
  build osmo-pcu
  build osmo-hlr
  build osmo-mgw
  build osmo-msc
  build osmo-bsc
  build simtrace2

  cd "$TOP/$PROJ"
  osc ci -m "Latest Tagged versions of $DT"
}

build_osmocom
