#!/bin/bash
# Generate source packages and upload them to OBS, for the nightly or next feed.
# Environment variables:
# * FEED: the binary package feed to upload to, this also controls the source branch that is used:
#   * "nightly": use "master" branch (default)
#   * "next": use "next" branch if it exists, otherwise use "master" branch
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/common-obs.sh"

set -e
set -x

DT=$(date +%Y%m%d)
TOP=$(pwd)/$(mktemp -d nightly-3g_XXXXXX)

# Set FEED and PROJ, based on the FEED env var
parse_feed_proj() {
  FEED="${FEED:-nightly}"
  case "$FEED" in
  nightly)
    PROJ=network:osmocom:nightly
    ;;
  next)
    PROJ=network:osmocom:next
    ;;
  *)
    echo "unsupported feed: $FEED"
    exit 1
    ;;
  esac
}

### OBS build
prepare() {
  # clean up the whole space
  mkdir -p "$REPO/osc/"
  cd "$REPO/osc"
  osc co "$PROJ"

  cd "$REPO"
  case "$FEED" in
  nightly)
    osmo_obs_prepare_conflict "osmocom-nightly" "osmocom-latest" "osmocom-next"
    ;;
  next)
    osmo_obs_prepare_conflict "osmocom-next" "osmocom-latest" "osmocom-nightly"
    ;;
  esac
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
  local url=$2
  local branch=$3

  if [ -z "$url" ]; then
    url="$(osmo_git_clone_url "$name")"
  fi

  cd "$REPO"

  if [ -n "$branch" ] ; then
    osmo_git_clone_date "$url" -b "$branch"
  else
    osmo_git_clone_date "$url"
  fi

  if [ "$FEED" = "next" ] && git -C "$name" show-branch remotes/origin/next >/dev/null 2>&1; then
    git -C "$name" checkout next
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
    osmo_obs_add_debian_dependency "./debian/control" "osmocom-$FEED"
    dch -b -v "$VER" -m "Snapshot build"
    git commit -m "$VER snapshot" debian/
  fi

  mkdir -p "$DATA/$name"
  if [ "$name" = "open5gs" ]; then
    # we cannot control the output directory of the generated source :(
    dpkg-buildpackage -S -uc -us -d
    mv "../$name"*.tar* "../$name"*.dsc "$DATA/$name/"
  elif [ -f .tarball-version ]; then
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
  osmo_obs_add_rpm_spec "$oscdir" "$repodir" "$name"
  osc ci -m "Snapshot $name $DT" --noservice
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

checkout_open5gs() {
  cd "$REPO"
  git clone https://github.com/open5gs/open5gs
  cd open5gs
  meson subprojects download freeDiameter
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

  # NOTE: when adding a repository that is not in gerrit, adjust osmo_git_clone_url()
  checkout_limesuite
  checkout osmo-gsm-manuals
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
  checkout_open5gs
  checkout neocon https://github.com/laf0rge/neocon
  checkout osmo-uecups

  cd "$REPO"
  osmo_obs_checkout_copy debian8 osmo-gsm-manuals
  osmo_obs_checkout_copy debian8 osmo-trx
  osmo_obs_checkout_copy debian10 limesuite

  build osmocom-$FEED
  build limesuite no_commit --git-upstream-tree="$(get_last_tag limesuite)"
  build limesuite-debian10 no_commit --git-upstream-tree="$(get_last_tag limesuite)"
  build osmo-gsm-manuals
  build osmo-gsm-manuals-debian8
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
  build osmo-trx-debian8
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
  build open5gs
  build neocon
  build osmo-uecups

  download_bumpversion

  post
}

parse_feed_proj
build_osmocom
