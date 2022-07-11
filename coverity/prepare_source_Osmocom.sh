#!/bin/sh
BASEDIR=source-Osmocom

PROJECTS="
  libasn1c
  libosmo-abis
  libosmocore
  libosmo-dsp
  libosmo-netif
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

[ -d $BASEDIR ] || mkdir -p $BASEDIR
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
		git clone git://git.osmocom.org/$proj
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
	git clone https://git.sysmocom.de/sysmo-bts/layer1-api
fi
