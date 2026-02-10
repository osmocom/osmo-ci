#!/bin/sh -ex
IMAGE="debian-bookworm-osmo-ttcn3-testenv"
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
LINUX_GIT_DIR="$1"
LINUX_REPO_BRANCH="$2"

test -d "$LINUX_GIT_DIR"
test -n "$LINUX_REPO_BRANCH"

mkdir -p output

podman run \
	--rm \
	-v "$LINUX_GIT_DIR:/linux.git:ro" \
	-v "$SCRIPT_DIR:/scripts/kernel/" \
	-v "$PWD/output:/output" \
	"$IMAGE" \
	timeout 3h sh -exc "
		git config --global --add safe.directory /linux.git
		git -C /linux.git log -1 --oneline $LINUX_REPO_BRANCH
		git clone -q /linux.git -b $LINUX_REPO_BRANCH /linux
		cd /linux

		make defconfig
		scripts/kconfig/merge_config.sh -m .config /scripts/kernel/fragment.config
		make olddefconfig
		make -j$(nproc)
		cp arch/x86/boot/bzImage /output/linux
	" | tee output/build.log
