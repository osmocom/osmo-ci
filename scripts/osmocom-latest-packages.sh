#!/bin/sh
# Generate source packages and upload them to OBS, for the latest feed.
# New packages are only uploaded if the source changed.
# Environment variables:
# * PROJ: the OBS namespace to upload to (e.g. "network:osmocom:latest")
# * FEED:
#   * "latest": use latest tagged release (default)
#   * other: use last commit of branch of same name, exit with error if it does
#     not exist
# * PACKAGES: set to a space-separated list of packages to skip all others
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/common-obs.sh"

# Values for FEED env var. Adjust FEEDS_ALL in common-obs when changing.
FEEDS="
  latest
"

set -e
set -x

DT=$(date +%Y%m%d%H%M)
TOP=$(pwd)
DEBSRCDIR="$TOP/debsrc"
FEED="${FEED:-latest}"

### OBS build
prepare() {
  # start with a checkout of the project
  if [ -d $PROJ ]; then
    (cd $PROJ && osc up)
  else
    osc co $PROJ
  fi
  [ -d "$DEBSRCDIR" ] && rm -rf "$DEBSRCDIR"
  mkdir "$DEBSRCDIR"

  cd "$TOP"
  osmo_obs_prepare_conflict
}

get_last_tag() {
  project="$1"
  if [ "$project" = "limesuite" ] || [ "$project" = "open5gs" ]; then
    ver_regexp="^v[0-9]*.[0-9]*.[0-9]*$"
  else
    ver_regexp="^[0-9]*.[0-9]*.[0-9]*$"
  fi
  VER=$(git -C "${TOP}/${project}" tag -l --sort=v:refname | grep "$ver_regexp" | tail -n 1)
  echo "${VER}"
}

checkout() {
  project=$1
  url=$2
  gitbpargs=""

  if osmo_obs_skip_pkg "$project"; then
    return
  fi

  if [ -z "$url" ]; then
    url="$(osmo_git_clone_url "$project")"
  fi

  echo
  echo "====> Checking out $project"
  cd "$TOP"
  [ -d "$project" ] || osmo_git_clone_date "$url" "$project"
  cd "$project"
  git fetch

  if [ "$FEED" = "latest" ]; then
    VER=$(get_last_tag "$project")
    git checkout -f -B "$VER" "refs/tags/$VER"
  else
    git checkout -f -B "$FEED" "origin/$FEED"
  fi

  if [ "$project" = "open5gs" ]; then
      meson subprojects download freeDiameter
  fi
}

# Generate a source package and upload it to OBS
# $1: package name (e.g. "libosmocore")
# $2: arguments to pass to "gbp buildpackage"
build() {
  project=$1
  gitbpargs="$2"
  output="$DEBSRCDIR/$project"

  if osmo_obs_skip_pkg "$project"; then
    return
  fi

  echo
  echo "====> Building $project"
  cd "$TOP/$project"

  osmo_obs_git_version_gen

  if [ "$FEED" = "latest" ]; then
    debian_branch=$(get_last_tag "$project")
  else
    debian_branch="$FEED"
    # Set new debian changelog version with commit appended. This version will
    # become part of resulting filenames, and will change if commits have been
    # added to the feed's branch.
    VER="$(osmo_obs_get_commit_version)"
    dch -b -v "$VER" -m "Snapshot build"
    git commit -m "$VER snapshot" debian/
  fi

  osmo_obs_add_depend_deb "./debian/control" "$project" "osmocom-$FEED"

  if [ "$project" = "open5gs" ]; then
    # we cannot control the output directory of the generated source :(
    dpkg-buildpackage -S -uc -us -d
    mkdir -p "$output"
    mv "../$name"*.tar* "../$name"*.dsc "$output"
  elif [ -x ./git-version-gen ]; then
    gbp buildpackage -S -uc -us -d --git-ignore-branch "--git-export-dir=$output" \
		     "--git-debian-branch=$debian_branch" --git-ignore-new $gitbpargs \
		     --git-postexport='cp $GBP_GIT_DIR/../.tarball-version $GBP_TMP_DIR/'
  else
    gbp buildpackage -S -uc -us -d --git-ignore-branch "--git-export-dir=$output" \
		     "--git-debian-branch=$debian_branch" --git-ignore-new $gitbpargs
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

  osmo_obs_add_rpm_spec "$TOP/$PROJ/$project" "$TOP/$project" "$project" "osmocom-$FEED"

  cd "$TOP"
}

# add those once they have tagged any versions that include the 'debian' sub-dir:
#rtl-sdr
#osmo-fl2k

build_osmocom() {
  prepare

  # NOTE: when adding a repository that is not in gerrit, adjust osmo_git_clone_url()
  checkout limesuite https://github.com/myriadrf/LimeSuite
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
  checkout simtrace2
  checkout libosmo-dsp
  checkout osmo-sysmon
  checkout osmo-remsim
  checkout open5gs https://github.com/open5gs/open5gs
  checkout neocon https://github.com/laf0rge/neocon
  checkout osmo-uecups
  checkout osmo-e1d
  checkout osmo-smlc
  checkout osmo-cbc
  checkout osmo-gbproxy

  cd "$TOP"

  build osmocom-$FEED
  build limesuite --git-upstream-tree="$(get_last_tag limesuite)"
  build osmo-gsm-manuals
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
  build osmo-sip-connector
  build osmo-bts
  build osmo-pcu
  build osmo-hlr
  build osmo-mgw
  build osmo-msc
  build osmo-bsc
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

  cd "$TOP/$PROJ"
  osc ci -m "$FEED versions of $DT" --noservice
}

osmo_obs_verify_feed
build_osmocom
