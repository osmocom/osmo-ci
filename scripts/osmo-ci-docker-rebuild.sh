#!/bin/sh
set -e -x
cd "$(dirname "$0")/.."
. scripts/common.sh

case "$(arch)" in
x86_64)
	# debian-bullseye-jenkins: has python2 (OS#5950)
	docker_images_require \
		"debian-bookworm-build" \
		"debian-bookworm-erlang" \
		"debian-bullseye-jenkins"
	;;
arm*)
	docker_images_require \
		"debian-bookworm-build-arm"
	;;
esac
