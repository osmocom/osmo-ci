#!/bin/sh
set -e -x
cd "$(dirname "$0")/.."
. scripts/common.sh
docker_images_require \
	"debian-stretch-jenkins" \
	"debian-buster-erlang"
