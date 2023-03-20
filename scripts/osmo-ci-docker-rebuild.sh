#!/bin/sh
set -e -x
cd "$(dirname "$0")/.."
. scripts/common.sh

case "$(arch)" in
x86_64)
	docker_images_require \
		"debian-bullseye-erlang" \
		"debian-bullseye-jenkins" \
		"debian-buster-jenkins"
	;;
arm*)
	docker_images_require \
		"debian-bullseye-jenkins-arm" \
		"debian-buster-jenkins-arm"
	;;
esac
