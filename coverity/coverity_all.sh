#!/usr/bin/env bash

set -e -x

base_dir="$PWD"
src_dir="$base_dir/source"
prefix="$base_dir/install"

install -d "$prefix"

export PATH="$base_dir/cov-analysis-linux64-8.5.0/bin/:$PATH"
export PKG_CONFIG_PATH="$prefix/lib/pkgconfig"

do_build() {
	git clean -dxf
	git remote prune origin
	git pull --rebase
	autoreconf --install --force
	./configure --prefix="$prefix" $*

	cov-build --dir cov-int make
	make install
	rm -f myproject.tgz
	tar czf myproject.tgz cov-int	
}

do_upload() {
	project="$1"
	token="$("$base_dir"/get_token.sh "$base_dir"/tokens.txt $project)"
	curl \
		--form token=$token \
		--form email=holger@freyther.de --form file=@myproject.tgz \
		--form version=Version --form description=AutoUpload \
		https://scan.coverity.com/builds?project=$project
}

upload_libosmocore() {
	pushd libosmocore

	do_build
	do_upload libosmocore
	popd
}

upload_libosmoabis() {
	pushd libosmo-abis

	do_build
	do_upload libosmo-abis
	popd
}

upload_libosmosccp() {
	pushd libosmo-sccp

	do_build
	do_upload libosmo-sccp
	popd
}

upload_openggsn() {
	pushd openggsn
	do_build
	do_upload OpenGGSN
	popd
}

upload_openbsc() {
	pushd openbsc/openbsc

	do_build --enable-osmo-bsc --enable-nat --enable-smpp --enable-mgcp-transcoding
	do_upload OpenBSC
	popd
}

upload_osmobts() {
	pushd osmo-bts

	do_build --enable-sysmocom-bts --with-openbsc="$src_dir/openbsc/openbsc/include"
	do_upload osmo-bts
	popd
}

upload_osmopcu() {
	pushd osmo-pcu 

	do_build --enable-sysmocom-bts=yes --enable-sysmocom-dsp=yes
	do_upload osmo-pcu
	popd
}

upload_libosmodsp() {
	pushd libosmo-dsp
	do_build
	do_upload libosmo-dsp
	popd
}

upload_libosmonetif() {
	pushd libosmo-netif
	do_build
	do_upload libosmo-netif
	popd
}

upload_osmogmr() {
	pushd osmo-gmr
	do_build
	do_upload osmo-gmr
	popd
}

build_libsmpp34() {
	pushd libsmpp34
	do_build
	popd
}

build_api() {
        pushd layer1-api
        install -d "$prefix/include/sysmocom/femtobts/"
        cp include/*.h "$prefix/include/sysmocom/femtobts/"
        popd
}

cd source

upload_libosmocore
upload_libosmoabis
upload_libosmonetif
upload_libosmosccp
build_libsmpp34
build_api
upload_openggsn
upload_openbsc
upload_osmopcu

# GMR
upload_libosmodsp
upload_osmogmr

# last.. as currently broken
upload_osmobts
