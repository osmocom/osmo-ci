#!/bin/bash
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/common-obs.sh"

# requirements
# apt install devscripts git-buildpackage osc git

set -e
set -x

# OBS project name
PROJ=home:pespin:branches:network:osmocom:nightly

DT=$(date +%Y%m%d)
TOP=$(pwd)/$(mktemp -d nightly-3g_XXXXXX)

if ! which osc >/dev/null 2>/dev/null ; then
  echo "osc binary not found"
  exit 1
fi

### OBS build
prepare() {
  # clean up the whole space
  mkdir -p "$REPO/osc/"
  cd "$REPO/osc"
  osc co "$PROJ"

  cd "$REPO"
  osmo_obs_prepare_conflict "osmocom-nightly" "osmocom-latest"
}

get_last_tag() {
  project="$1"
  if [ "$project" = "limesuite" ]; then
    ver_regexp="^v[0-9]*.[0-9]*.[0-9]*$"
  else
    ver_regexp="^[0-9]*.[0-9]*.[0-9]*$"
  fi
  VER=$(git -C "${REPO}/${project}" tag -l --sort=v:refname | grep "$ver_regexp" | tail -n 1)
  echo "${VER}"
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

### common
checkout() {
  local name=$1
  local branch=$2
  local url="https://git.osmocom.org"

  cd "$REPO"

  if [ -n "$branch" ] ; then
    osmo_git_clone_date "$url/$name" -b "$branch"
  else
    osmo_git_clone_date "$url/$name"
  fi

  cd -
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
    osmo_obs_add_debian_dependency "./debian/control" "osmocom-nightly"
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
  cd "$REPO"
  git clone https://github.com/myriadrf/LimeSuite limesuite
  TAG="$(get_last_tag limesuite)"
  cd limesuite
  git checkout "$TAG"
}

# Copy an already checked out repository dir and apply its debian 8 patch.
# $1: Osmocom repository
checkout_copy_debian8_jessie() {
  cd "$REPO"
  cp -a "$1" "$1-debian8-jessie"
  cd "$1-debian8-jessie"
  patch -p1 < debian/patches/build-for-debian8.patch
  git commit -m 'auto-commit: allow debian8 to build' debian/
  cd ..
}

build_osmocom() {
  DATA=$TOP/data
  REPO=$TOP/repo

  # rather than including a dangerous 'rm -rf *' here, lets delegate to the user:
  if [ -n "$(ls $TOP)" ]; then
    echo "ERROR: I need to run in an empty directory."
    exit 1
  fi

  prepare

  checkout osmo-gsm-manuals
  checkout libosmocore
  checkout libosmo-sccp
  checkout libosmo-abis
  checkout libosmo-netif
  checkout libasn1c
  checkout osmo-iuh pespin/fix-sabp

  checkout_copy_debian8_jessie "osmo-gsm-manuals"

  build osmocom-nightly
  build osmo-gsm-manuals
  build osmo-gsm-manuals-debian8-jessie
  build libosmocore
  build libosmo-sccp
  build libosmo-abis
  build libosmo-netif
  build libasn1c
  build osmo-iuh

  download_bumpversion

  post
}

build_osmocom
