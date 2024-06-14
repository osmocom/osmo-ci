#!/usr/bin/env bash
# Use 'local_test.sh' during development

set -e -x

readlink /opt/coverity/current

export PATH=$PATH:/opt/coverity/current/bin

base_dir="/opt/osmo-ci/coverity"
src_dir="$PWD/source-Osmocom"
cov_dir="$src_dir/cov-int"

rm -rf "$src_dir"
./prepare_source_Osmocom.sh

export PATH="$base_dir/cov-analysis-linux64-8.5.0/bin/:$PATH"

rm -rf "$cov_dir"
cov-build --dir "$cov_dir" ./build_Osmocom.sh

cd "$src_dir"
rm -f Osmocom.tgz
tar czf Osmocom.tgz cov-int

# Don't leak the token to jenkins build logs, but still log the call:
# First compose the call to echo, then run with token inserted by 'eval'.
set +x

curl_cmd='curl \
 --form token="$token" \
 --form email=holger@freyther.de --form file=@Osmocom.tgz \
 --form version=Version --form description=AutoUpload \
 https://scan.coverity.com/builds?project=Osmocom'
echo "$curl_cmd"

token="$($base_dir/get_token.sh $base_dir/tokens.txt Osmocom)"
if [ -z "$token" ]; then
  echo "TOKEN IS EMPTY"
  exit 1
fi

eval "$curl_cmd"
