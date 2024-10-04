#!/bin/sh -ex
IMAGE="debian-bookworm-osmo-ttcn3-testenv"
SCRIPT_DIR="$(realpath "$(dirname "$0")")"

mkdir -p output

podman run \
	--rm \
	-v "$SCRIPT_DIR:/scripts/kernel/" \
	-v "$PWD:$PWD" \
	-w "$PWD" \
	"$IMAGE" \
	timeout 3h sh -exc '
		make defconfig
		scripts/kconfig/merge_config.sh -m .config /scripts/kernel/fragment.config
		make olddefconfig
		make "-j$(nproc)"
		cp arch/x86/boot/bzImage output/linux
	' | tee output/build.log
