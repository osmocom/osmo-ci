#!/usr/bin/env bash

set -e -x

export PKG_CONFIG_PATH=~/coverity/install-iuh/lib/pkgconfig

do_build() {
	git clean -dxf
	git checkout .
	git remote prune origin
	git pull --rebase
	autoreconf --install --force
	./configure --prefix=$HOME/coverity/install-iuh $*

	make
	make install
}

build_layer1api() {
	pushd layer1-api
	install -d $HOME/coverity/install-iuh/include/sysmocom/femtobts/
	cp include/*.h $HOME/coverity/install-iuh/include/sysmocom/femtobts/
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
	sed -i s,'#include "config.h"','/*#include "config.h"*/', $HOME/coverity/install-iuh/include/asn1c/asn_system.h
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
	git checkout sysmocom/iu

	do_build --enable-osmo-bsc --enable-nat --enable-smpp --enable-mgcp-transcoding --enable-iu
	popd
}

build_osmobts() {
	pushd openbsc/openbsc
	git checkout master
	git pull --rebase
	popd
	pushd osmo-bts

	do_build --enable-sysmocom-bts --with-openbsc=$PWD/../openbsc/openbsc/include
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

cd source-iuh


rm -rf ~/coverity/install-iuh/

build_layer1api
build_asn1c
build_libosmocore
build_libasn1c
build_libosmoabis
build_libosmonetif
build_libosmosccp
build_libsmpp34
build_openggsn
build_osmoiuh
build_osmopcu
build_osmobts
build_openbsc

# GMR
build_libosmodsp
build_osmogmr

# MNCC to SIP
build_osmosipconnector
