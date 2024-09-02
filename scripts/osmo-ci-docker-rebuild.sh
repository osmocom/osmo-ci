#!/bin/sh
set -e -x
cd "$(dirname "$0")/.."
. scripts/common.sh

case "$(arch)" in
x86_64)
	docker_images_require \
		"debian-bookworm-build" \
		"debian-bookworm-erlang"
	;;
arm*|aarch64)
	docker_images_require \
		"debian-bookworm-build-arm"
	;;
esac
