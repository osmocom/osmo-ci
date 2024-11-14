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
	# OS#6627: need to run a separate "docker pull" command with platform
	docker pull docker.io/arm32v7/debian:bookworm --platform="linux/arm/v7"

	export NO_DOCKER_IMAGE_PULL=1
	docker_images_require \
		"debian-bookworm-build-arm"
	;;
esac
