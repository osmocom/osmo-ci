#!/usr/bin/env bash

set -e -x

base_dir="$PWD"
src_dir="$base_dir/source-Osmocom"
prefix="$base_dir/install-Osmocom"

install -d "$prefix"

export PKG_CONFIG_PATH="$prefix/lib/pkgconfig"

do_build() {
	autoreconf --install --force
	./configure \
		--prefix="$prefix" \
		--with-systemdsystemunitdir=no \
		--disable-doxygen \
		$*

	make $PARALLEL_MAKE
	make install
}

build_default() {
	pushd $1
	shift
	do_build $*
	popd
}

build_layer1api() {
	pushd layer1-api
	install -d "$prefix/include/sysmocom/femtobts/"
	cp include/*.h "$prefix/include/sysmocom/femtobts/"
	popd
}

build_libasn1c() {
	pushd libasn1c
	do_build
	sed -i s,'#include "config.h"','/*#include "config.h"*/', "$prefix/include/asn1c/asn_system.h"
	popd
}

build_libusrp() {
	pushd libusrp
	PM=$PARALLEL_MAKE
	PARALLEL_MAKE=""
	do_build
	PARALLEL_MAKE=$PM
	popd
}

build_osmocombb() {
	pushd osmocom-bb/src/
	make nofirmware
	popd
}

build_simtrace2() {
	pushd simtrace2/host
	do_build
	popd
}

cd "$src_dir"

rm -rf "$prefix"

build_layer1api
build_default asn1c
build_default libosmocore
build_libasn1c
build_libusrp
build_default libosmo-abis
build_default libosmo-gprs
build_default libosmo-netif
build_default libosmo-pfcp
build_default libosmo-sccp
build_default libsmpp34
build_default osmo-ggsn
build_default osmo-gbproxy
build_default osmo-iuh
build_default osmo-pcu \
	--with-sysmobts="$prefix/include/" \
	--enable-sysmocom-dsp=yes
build_default osmo-bts \
	--with-sysmobts="$prefix/include/" \
	--enable-sysmocom-bts \
	--enable-trx
build_default osmo-sysmon
build_default osmo-mgw
build_default osmo-bsc
build_default osmo-hlr
build_default osmo-msc \
	--enable-smpp \
	--enable-iu
build_default osmo-sgsn \
	--enable-iu
build_default osmo-smlc
build_default osmo-cbc
build_default osmo-hnodeb
build_default osmo-hnbgw
build_default osmo-bsc-nat

# GMR
build_default libosmo-dsp
build_default osmo-gmr

# MNCC to SIP
build_default osmo-sip-connector

build_default osmo-trx \
	--with-mstrx \
	--with-usrp1 \
	--with-uhd \
	--with-lms \
	--with-ipc

# OsmocomBB (without firmware)
build_osmocombb
# SIMTrace host tools
build_simtrace2

build_default osmo-pcap
build_default osmo-e1d
build_default osmo-e1-recorder
build_default osmo-upf
build_default osmo-isdntap
build_default osmo-uecups
build_default osmo-remsim
