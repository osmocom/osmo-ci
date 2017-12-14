#!/usr/bin/env bash

set -e -x

base_dir="$PWD"
src_dir="$base_dir/source-Osmocom"
prefix="$base_dir/install-Osmocom"

install -d "$prefix"

export PKG_CONFIG_PATH="$prefix/lib/pkgconfig"

git_branch() {
  echo "$(git status)" | grep 'On branch' | sed 's/On branch //'
}

do_build() {
	autoreconf --install --force
	./configure --prefix="$prefix" $*

	make $PARALLEL_MAKE
	make install
}

build_default() {
	pushd $1
	do_build
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

build_osmobts() {
	pushd osmo-bts

	do_build --enable-sysmocom-bts --enable-trx
	popd
}

build_osmopcu() {
	pushd osmo-pcu 

	do_build --enable-sysmocom-bts=yes --enable-sysmocom-dsp=yes
	popd
}

build_libsmpp34() {
	pushd libsmpp34
	PM=$PARALLEL_MAKE
	PARALLEL_MAKE=""
	do_build
	PARALLEL_MAKE=$PM
	popd
}

cd "$src_dir"

rm -rf "$prefix"

build_layer1api
build_default asn1c
build_default libosmocore
build_libasn1c
build_default libosmo-abis
build_default libosmo-netif
build_default libosmo-sccp
build_libsmpp34
build_default osmo-ggsn
#IU build_default osmo-iuh
build_osmopcu
build_osmobts
build_default osmo-mgw
build_default osmo-bsc
build_default osmo-msc
build_default osmo-hlr
build_default osmo-sgsn

# GMR
build_default libosmo-dsp
build_default osmo-gmr

# MNCC to SIP
build_default osmo-sip-connector

build_default osmo-trx
