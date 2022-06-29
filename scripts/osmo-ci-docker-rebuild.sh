#!/bin/sh
set -e -x
cd "$(dirname "$0")/.."
. scripts/common.sh
docker_images_require \
	"debian-stretch-jenkins" \
	"debian-buster-jenkins"

if [ "$(arch)" = "i686" ] && \
		grep -q '^ID=debian' /etc/os-release && \
		grep -q '^VERSION_ID="10"' /etc/os-release; then
	# Attempting to run debian-bullseye (11) in docker on debian 10 x86
	# doesn't work. Skip it here for gtp0-deb10build32 until we've moved it
	# away from debian 10.
	echo "Skipping build of debian-bullseye-erlang (OS#5453)"
else
	docker_images_require \
		"debian-bullseye-erlang"
fi

if [ -d "/var/tmp/osmo-gsm-tester/state" ]; then
	docker_images_require \
		"osmo-gsm-tester"
fi
