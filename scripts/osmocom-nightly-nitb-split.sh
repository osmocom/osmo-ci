#!/bin/bash

set -e
set -x

DT=$(date +%Y%m%d)
PROJ=network:osmocom:nitb-split:nightly

### common
checkout() {
  local name=$1
  local branch=$2
  local url="git://git.osmocom.org"

  cd "$REPO"

  if [ -n "$branch" ] ; then
    git clone "$url/$name" -b "$branch"
  else
    git clone "$url/$name"
  fi

  cd -
}

### OBS build
prepare() {
  # clean up the whole space
  mkdir -p "$REPO/osc/"
  cd "$REPO/osc"
  osc co "$PROJ"
}

build() {
  local name=$1
  local repodir=$REPO/$name
  local oscdir=$REPO/osc/$PROJ/$name

  if [ -d "$oscdir" ] ; then
    # remove earlier version
    cd "$oscdir"
    osc rm -- * || true
  else
    # new package
    mkdir -p "$oscdir/"
    cd "$REPO/osc/$PROJ/"
    osc add "$name"
  fi

  cd "$repodir"

  VER=$(head -1 debian/changelog | cut -d ' ' -f 2 | sed 's,(,,'  | sed 's,),,')
  dch -v "$VER.$DT" -m "Snapshot build"
  git commit -m "$DT snapshot" debian/

  mkdir -p "$DATA/$name"
  # source code build without dependency checks and unsigned source and unsigned change log
  gbp buildpackage -S -uc -us -d --git-ignore-branch "--git-export-dir=$DATA/$name"

  mv "$DATA/$name/"*.tar* "$DATA/$name/"*.dsc "$oscdir/"

  cd "$oscdir"
  osc add -- *.tar* *.dsc
  osc ci -m "Snapshot $name $DT"
}

post() {
  cd "$REPO/osc/$PROJ/"
  osc status
}

build_osmocom() {
  BASE=$PWD
  DATA=$BASE/data
  REPO=$BASE/repo

  # rather than including a dangerous 'rm -rf *' here, lets delegate to the user:
  if [ -n "$(ls)" ]; then
    echo "ERROR: I need to run in an empty directory."
    exit 1
  fi

  prepare

  checkout libosmocore
  checkout libosmo-abis
  checkout libosmo-netif
  checkout libosmo-sccp
  checkout libsmpp34
  checkout libasn1c
  checkout osmo-iuh
  checkout osmo-hlr
  checkout openggsn
  checkout osmo-mgw
  checkout osmo-bsc
  checkout osmo-msc
  checkout osmo-sgsn

  build libosmocore
  build libosmo-abis
  build libosmo-netif
  build libosmo-sccp
  build libsmpp34
  build libasn1c
  build osmo-iuh
  build osmo-hlr
  build openggsn
  build osmo-mgw
  build osmo-bsc
  build osmo-msc
  build osmo-sgsn

  post
}

TMPDIR=$(mktemp -d nightly-3g_XXXXXX)
cd "$TMPDIR"
build_osmocom
rm -rf "./$TMPDIR/"
