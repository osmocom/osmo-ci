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

	make
	make install
}

build_layer1api() {
	pushd layer1-api
	install -d "$prefix/include/sysmocom/femtobts/"
	cp include/*.h "$prefix/include/sysmocom/femtobts/"
	popd
}

build_asn1c() {
	pushd asn1c
	do_build
	popd
}

build_libasn1c() {
	pushd libasn1c
	do_build
	sed -i s,'#include "config.h"','/*#include "config.h"*/', "$prefix/include/asn1c/asn_system.h"
	popd
}

build_osmoiuh() {
	pushd osmo-iuh
	do_build
	popd
}

build_libosmocore() {
	pushd libosmocore

	do_build
	popd
}

build_libosmoabis() {
	pushd libosmo-abis

	do_build
	popd
}

build_libosmosccp() {
	pushd libosmo-sccp

	do_build
	popd
}

build_openggsn() {
	pushd openggsn
	do_build
	popd
}

build_openbsc() {
	pushd openbsc/openbsc
	#IU git checkout sysmocom/iu

	do_build --enable-osmo-bsc --enable-nat --enable-smpp --enable-mgcp-transcoding #IU --enable-iu
	popd
}

build_osmohlr() {
	pushd osmo-hlr
	do_build
	popd
}

build_osmobts() {
	#IU pushd openbsc/openbsc
	#IU git checkout master
	#IU git pull --rebase
	#IU popd
	pushd osmo-bts

	do_build --enable-sysmocom-bts --with-openbsc="$src_dir/openbsc/openbsc/include"
	popd
}

build_osmopcu() {
	pushd osmo-pcu 

	do_build --enable-sysmocom-bts=yes --enable-sysmocom-dsp=yes
	popd
}

build_libosmodsp() {
	pushd libosmo-dsp
	do_build
	popd
}

build_libosmonetif() {
	pushd libosmo-netif
	do_build
	popd
}

build_osmogmr() {
	pushd osmo-gmr
	do_build
	popd
}

build_libsmpp34() {
	pushd libsmpp34
	do_build
	popd
}

build_osmosipconnector() {
	pushd osmo-sip-connector
	do_build
	popd
}

build_osmotrx() {
	pushd osmo-trx
	do_build
	popd
}

cd "$src_dir"

rm -rf "$prefix"

build_layer1api
build_asn1c
build_libosmocore
build_libasn1c
build_libosmoabis
build_libosmonetif
build_libosmosccp
build_libsmpp34
build_openggsn
#IU build_osmoiuh
build_osmopcu
build_osmobts
build_openbsc
build_osmohlr

# GMR
build_libosmodsp
build_osmogmr

# MNCC to SIP
build_osmosipconnector

build_osmotrx
