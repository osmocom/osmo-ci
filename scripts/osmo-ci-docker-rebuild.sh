#!/bin/sh
set -e -x
cd "$(dirname "$0")/.."
. scripts/common.sh
docker_images_require \
	"debian-stretch-jenkins" \
	"debian-buster-jenkins" \
	"debian-bullseye-erlang" \

if [ "$(arch)" = "x86_64" ]; then
	docker_images_require \
		"osmo-gsm-tester"
fi
