#!/usr/bin/env bash

set -e -x

base_dir="$PWD"
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
	tar czf myproject.tgz cov-int	
}

do_upload() {
	curl \
		--form token=$2 \
		--form email=holger@freyther.de --form file=@myproject.tgz \
		--form version=Version --form description=AutoUpload \
		https://scan.coverity.com/builds?project=$1
	:
}

upload_osmotrx() {
	pushd osmo-trx

	do_build
	#do_upload osmo-trx Insert-Coverity-Token-Here
	popd
}


cd source

upload_osmotrx

