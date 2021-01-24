#!/bin/sh
# Generate source packages and upload them to OBS, for the latest feed.
. "$(dirname "$0")/common.sh"
. "$(dirname "$0")/common-obs.sh"

set -e
set -x

# OBS project name
PROJ=network:osmocom:latest

DT=$(date +%Y%m%d%H%M)
TOP=$(pwd)
DEBSRCDIR="$TOP/debsrc"

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
  osmo_obs_prepare_conflict "osmocom-latest" "osmocom-nightly" "osmocom-next"
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

  if [ -z "$url" ]; then
    url="$(osmo_git_clone_url "$project")"
  fi

  echo
  echo "====> Checking out $project"
  cd "$TOP"
  [ -d "$project" ] || osmo_git_clone_date "$url" "$project"
  cd "$project"
  git fetch
  VER=$(get_last_tag "$project")
  git checkout -f -B "$VER" "refs/tags/$VER"
  if [ "$project" = "open5gs" ]; then
      meson subprojects download freeDiameter
  fi
}

build() {
  project=$1
  gitbpargs="$2"
  output="$DEBSRCDIR/$project"
  echo
  echo "====> Building $project"
  cd "$TOP/$project"
  VER=$(get_last_tag "$project")
  if [ -x ./git-version-gen ]; then
    ./git-version-gen . > .tarball-version 2>/dev/null
  fi

  osmo_obs_add_depend_deb "./debian/control" "$project" "osmocom-latest"

  if [ "$project" = "open5gs" ]; then
    # we cannot control the output directory of the generated source :(
    dpkg-buildpackage -S -uc -us -d
    mkdir -p "$output"
    mv "../$name"*.tar* "../$name"*.dsc "$output"
  elif [ -x ./git-version-gen ]; then
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
    osmo_obs_add_rpm_spec "$TOP/$PROJ/$project" "$output" "$project" "osmocom-latest"
  else
    cd "$TOP/$PROJ/$project"

    # update OBS only if the filename doesn't match
    file=$(cd "$output/" ; ls ./*.dsc)
    if [ ! -e "$file" ] ; then
      osc rm ./* || true
      mv "$output/"*.dsc .
      mv "$output/"*.tar* .
      osc add ./*
      osmo_obs_add_rpm_spec "$PWD" "$output" "$project" "osmocom-latest"
    fi
  fi
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
  checkout osmo-cbc

  cd "$TOP"
  osmo_obs_checkout_copy debian8 osmo-gsm-manuals

  build osmocom-latest
  build limesuite --git-upstream-tree="$(get_last_tag limesuite)"
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
  # re-enable after libosmcoore > 1.3.1 is released (osmo_system_nowait2)
  #build osmo-uecups
  build osmo-e1d
  build osmo-cbc

  cd "$TOP/$PROJ"
  osc ci -m "Latest Tagged versions of $DT" --noservice
}

build_osmocom
