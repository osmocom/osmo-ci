#!/bin/sh -xe
. $(realpath common.sh)
BASEDIR=source-Osmocom

# How to add a new project:
# * add it to the list below
# * add it to build_Osmocom.sh
# * add it as component here:
#   https://scan.coverity.com/projects/osmocom?tab=analysis_settings

PROJECTS="
  libasn1c
  libosmo-abis
  libosmocore
  libosmo-dsp
  libosmo-gprs
  libosmo-netif
  libosmo-pfcp
  libosmo-sccp
  libsmpp34
  libusrp
  osmo-bsc
  osmo-msc
  osmo-mgw
  osmo-ggsn
  osmo-gbproxy
  osmo-sgsn
  osmo-bts
  osmo-gmr
  osmo-iuh
  osmo-pcu
  osmo-sysmon
  osmo-sip-connector
  osmo-trx
  osmo-hlr
  osmocom-bb
  osmo-smlc
  osmo-cbc
  simtrace2
  osmo-hnodeb
  osmo-hnbgw
  osmo-bsc-nat
"

PROJECTS_DONT_BUILD_TEST="
  asn1c
"

mkdir -p $BASEDIR
cd $BASEDIR

for proj in $PROJECTS $PROJECTS_DONT_BUILD_TEST; do
	if [ -d $proj ]; then
		if [ -z "$SRC_SKIP_FETCH" ]; then
			(cd $proj && git fetch && git checkout -f -B master origin/master)
		fi
		if [ -n "$SRC_CLEAN" ]; then
			git -C "$proj" clean -ffxd
		fi
	else
		git clone "$(osmo_git_clone_url "$proj")"
	fi
done

# We want to compile tests, but not execute them.  Using 'noinst_PROGRAMS'
# instead of 'check_PROGRAMS' allows building test binaries during 'make all'.
for proj in $PROJECTS; do
	files="$(git -C $proj grep -l check_PROGRAMS)"
	if [ -n "$files" ]; then
		(cd $proj && sed -i "s/check_PROGRAMS/noinst_PROGRAMS/" $files)
	fi
done

if ! [ -d layer1-api ]; then
	git clone https://gitea.sysmocom.de/sysmo-bts/layer1-api
fi
