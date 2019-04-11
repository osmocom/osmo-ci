#!/bin/bash
# requirements
# apt install devscripts git-buildpackage osc git

set -e
set -x

if ! which osc >/dev/null 2>/dev/null ; then
  echo "osc binary not found"
  exit 1
fi
DT=$(date +%Y%m%d)
PROJ=network:osmocom:nightly

### common
checkout() {
  local name=$1
  local branch=$2
  local url="https://git.osmocom.org"

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

get_commit_version() {
  # return a version based on the commit
  local version

  # determine git version *and generate the .tarball-version file*
  test -x ./git-version-gen && ./git-version-gen . > .tarball-version 2>/dev/null
  version=$(cat .tarball-version)
  # debian doesn't allow '-' in version.
  version=$(echo "$version" | sed  's/-/./g' )

  # deb version
  if [ -z "$version" ] ; then
    version=$(head -1 debian/changelog | cut -d ' ' -f 2 | sed 's,(,,'  | sed 's,),,')
    version="$version.$DT"
  fi

  echo -n "$version"
}

build() {
  local name=$1
  local changelog=$2
  local gitbpargs=$3
  local repodir=$REPO/$name
  local oscdir=$REPO/osc/$PROJ/$name

  if [ -z "$changelog" ] ; then
    changelog=commit
  fi

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

  if [ "$changelog" = "commit" ] ; then
    VER=$(get_commit_version)
    dch -b -v "$VER" -m "Snapshot build"
    git commit -m "$VER snapshot" debian/
  fi

  mkdir -p "$DATA/$name"
  # source code build without dependency checks and unsigned source and unsigned change log
  if [ -f .tarball-version ]; then
    gbp buildpackage -S -uc -us -d --git-ignore-branch "--git-export-dir=$DATA/$name" \
		     --git-ignore-new $gitbpargs \
		     --git-postexport='cp $GBP_GIT_DIR/../.tarball-version $GBP_TMP_DIR/'
  else
    gbp buildpackage -S -uc -us -d --git-ignore-branch "--git-export-dir=$DATA/$name" \
		     --git-ignore-new $gitbpargs
  fi

  mv "$DATA/$name/"*.tar* "$DATA/$name/"*.dsc "$oscdir/"

  cd "$oscdir"
  osc add -- *.tar* *.dsc
  osc ci -m "Snapshot $name $DT"
}

post() {
  cd "$REPO/osc/$PROJ/"
  osc status
}

download_bumpversion() {
  # bumpversion is required for debian < 9/stretch
  local oscdir=$REPO/osc/$PROJ/bumpversion
  local version=0.5.3
  local release=3

  if [ ! -d "$oscdir" ] ; then
    mkdir "$oscdir"
    cd "$oscdir"
    wget "http://http.debian.net/debian/pool/main/b/bumpversion/bumpversion_$version-$release.dsc"
    wget "http://http.debian.net/debian/pool/main/b/bumpversion/bumpversion_$version.orig.tar.gz"
    wget "http://http.debian.net/debian/pool/main/b/bumpversion/bumpversion_$version-$release.debian.tar.xz"
  fi
}

checkout_limesuite() {
  TAG="v18.10.0"

  cd "$REPO"
  git clone https://github.com/myriadrf/LimeSuite limesuite
  cd limesuite
  git checkout "$TAG"
}

create_osmo_trx_debian8_jessie() {
  # The package must be already checked out via `checkout osmo-trx`
  cd "$REPO"
  cp -a osmo-trx osmo-trx-debian8-jessie
  cd osmo-trx-debian8-jessie/
  patch -p1 < debian/patches/build-for-debian8.patch
  git commit -m 'auto-commit: allow debian8 to build' debian/
  cd ..
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

  checkout_limesuite
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
  checkout python/osmo-python-tests
  checkout rtl-sdr
  checkout osmo-fl2k
  checkout simtrace2
  checkout libosmo-dsp
  checkout osmo-sysmon
  checkout osmo-remsim

  create_osmo_trx_debian8_jessie

  build limesuite no_commit --git-upstream-tree=v18.10.0
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
  build osmo-trx-debian8-jessie
  build osmo-sip-connector
  build osmo-bts
  build osmo-pcu
  build osmo-hlr
  build osmo-mgw
  build osmo-msc
  build osmo-bsc
  build osmo-python-tests
  build rtl-sdr
  build osmo-fl2k
  build simtrace2
  build libosmo-dsp
  build osmo-sysmon
  build osmo-remsim

  download_bumpversion

  post
}

TMPDIR=$(mktemp -d nightly-3g_XXXXXX)
cd "$TMPDIR"
build_osmocom
