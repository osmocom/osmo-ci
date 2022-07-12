#!/bin/sh
set -e -x
cd "$(dirname "$0")/.."
. scripts/common.sh
docker_images_require \
	"debian-buster-jenkins"

if [ "$(arch)" = "x86_64" ]; then
	docker_images_require \
		"debian-bullseye-erlang"
fi

if [ -d "/var/tmp/osmo-gsm-tester/state" ]; then
	docker_images_require \
		"osmo-gsm-tester"
fi
