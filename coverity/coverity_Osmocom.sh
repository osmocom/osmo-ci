#!/usr/bin/env bash

set -e -x

base_dir="$PWD"
src_dir="$base_dir/source-Osmocom"
cov_dir="$src_dir/cov-int"

export PATH="$base_dir/cov-analysis-linux64-8.5.0/bin/:$PATH"

rm -rf "$cov_dir"
cov-build --dir "$cov_dir" ./build_Osmocom.sh

cd "$src_dir"
rm -f Osmocom.tgz
tar czf Osmocom.tgz cov-int

curl \
	--form token="$($base_dir/get_token.sh $base_dir/tokens.txt Osmocom)" \
	--form email=holger@freyther.de --form file=@Osmocom.tgz \
	--form version=Version --form description=AutoUpload \
	https://scan.coverity.com/builds?project=Osmocom
