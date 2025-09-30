#!/bin/sh
set -e -x
cd "$(dirname "$0")/.."
. scripts/common.sh

case "$(arch)" in
x86_64)
	# OS#6859: still need bookworm for osmo-opencm3-projects
	docker_images_require \
		"debian-bookworm-build" \
		"debian-bookworm-erlang" \
		"debian-trixie-build"
	;;
arm*|aarch64)
	# OS#6627: need to run a separate "docker pull" command with platform
	# OS#6858: still need bookworm for osmo-pcu
	docker pull docker.io/arm32v7/debian:bookworm --platform="linux/arm/v7"
	docker pull docker.io/arm32v7/debian:trixie --platform="linux/arm/v7"

	export NO_DOCKER_IMAGE_PULL=1
	docker_images_require \
		"debian-bookworm-build-arm" \
		"debian-trixie-build-arm"
	;;
esac
