#!/bin/sh
set -e -x
cd "$(dirname "$0")/.."
. scripts/common.sh
docker_images_require \
	"debian-stretch-jenkins" \
	"debian-buster-jenkins" \
	"debian-buster-erlang" \
	"osmo-gsm-tester"
