#!/bin/bash
# Generate source packages and upload them to OBS, for the nightly or next feed.
# New packages are always uploaded, even if the source does not change. Only
# packages of the same build date (DT) can be installed together.
# Environment variables:
# * PROJ: the OBS namespace to upload to (e.g. "network:osmocom:nightly")
# * FEED: controls the source branch that is used:
#   * "nightly": use "master" branch (default)
#   * "next": use "next" branch if it exists, otherwise use "master" branch
# * PACKAGES: set to a space-separated list of packages to skip all others
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/common-obs.sh"

set -e
set -x

DT=$(date +%Y%m%d%H%M)
OSMO_OBS_CONFLICT_PKGVER="$OSMO_OBS_CONFLICT_PKGVER.$DT"
TOP=$(pwd)/$(mktemp -d nightly-3g_XXXXXX)
FEED="${FEED:-nightly}"

if [ "$FEED" != "nightly" ] && [ "$FEED" != "next" ]; then
  echo "unsupported feed: $FEED"
  exit 1
fi

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

# Return a version based on the latest tag and commit (e.g. "1.5.1.93.47cc")
# or fall back to the last debian version (e.g. "2.2.6").
# Run osmo_obs_git_version_gen before. $PWD must be inside a git repository.
get_commit_version() {
  local version=""

  if [ -e ".tarball-version" ]; then
    version=$(cat .tarball-version)
    # debian doesn't allow '-' in version.
    version=$(echo "$version" | sed  's/-/./g' )
  fi

  # deb version
  deb_version=$(head -1 debian/changelog | cut -d ' ' -f 2 | sed 's,(,,'  | sed 's,),,')
  if [ -z "$version" ] || [ "$version" = "UNKNOWN" ]; then
    version="$deb_version"
  else
    # add epoch from debian/changelog
    case $deb_version in
    *:*)
      epoch=$(echo "$deb_version" | cut -d : -f 1)
      version=$epoch:$version
      ;;
    esac
  fi

  echo -n "$version"
}

### common
checkout() {
  local name=$1
  local url=$2
  local branch=$3

  if osmo_obs_skip_pkg "$name"; then
    return
  fi

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

# Generate a source package and upload it to OBS
# $1: package name (e.g. "libosmocore")
# $2: update debian dir, unless set to "no_commit":
#     * add dependency on osmocom-$FEED package
#     * add new version to changelog (e.g. "1.5.1.96.c96d7.202104281354")
# $3: arguments to pass to "gbp buildpackage"
build() {
  local name=$1
  local changelog=$2
  local gitbpargs=$3
  local repodir=$REPO/$name
  local oscdir=$REPO/osc/$PROJ/$name
  local dependver="$OSMO_OBS_CONFLICT_PKGVER"

  if osmo_obs_skip_pkg "$name"; then
    return
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

  if [ "$changelog" != "no_commit" ] ; then
    osmo_obs_git_version_gen
    # Add date to increase version even if commit did not change (OS#5135)
    VER="$(get_commit_version).$DT"
    osmo_obs_add_depend_deb "./debian/control" "$name" "osmocom-$FEED" "$dependver"
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
  osmo_obs_add_rpm_spec "$oscdir" "$repodir" "$name" "osmocom-$FEED" "$dependver"
  osc ci -m "Snapshot $name $DT" --noservice
}

post() {
  cd "$REPO/osc/$PROJ/"
  osc status
}

checkout_limesuite() {
  if osmo_obs_skip_pkg "limesuite"; then
    return
  fi

  cd "$REPO"
  git clone https://github.com/myriadrf/LimeSuite limesuite
  TAG="$(get_last_tag limesuite)"
  cd limesuite
  git checkout "$TAG"
}

checkout_open5gs() {
  if osmo_obs_skip_pkg "open5gs"; then
    return
  fi

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
  checkout osmo-e1d
  checkout osmo-smlc
  checkout osmo-cbc
  checkout osmo-gbproxy

  cd "$REPO"
  osmo_obs_checkout_copy debian8 osmo-gsm-manuals
  osmo_obs_checkout_copy debian8 osmo-trx

  build osmocom-$FEED no_commit
  build limesuite no_commit --git-upstream-tree="$(get_last_tag limesuite)"
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
  build osmo-e1d
  build osmo-smlc
  build osmo-cbc
  build osmo-gbproxy

  post
}

build_osmocom
