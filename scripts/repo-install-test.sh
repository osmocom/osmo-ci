#!/bin/sh -ex
# Environment variables:
# * INTERACTIVE: set to 1 to keep an interactive shell open after the script ran (for debugging)
# * FEED: binary package feed (e.g. "latest", "nightly")
# * PROJ: OBS project namespace (e.g. "osmocom:latest")
# * PROJ_CONFLICT: Conflicting OBS project namespace (e.g. "osmocom:nightly")
# * KEEP_CACHE: set to 1 to keep downloaded binary packages (for development)
# * TESTS: which tests to run (all by default, see below for possible values)
. "$(dirname "$0")/common.sh"

DISTRO="$1"
DISTROS="
	centos8
	debian10
	debian11
"

check_usage() {
	local i
	for i in $DISTROS; do
		if [ "$DISTRO" = "$i" ]; then
			return
		fi
	done
	echo "usage: repo-install-test.sh DISTRO"
	echo "DISTRO: one of: $DISTROS"
	exit 1
}

check_usage
docker_images_require "$DISTRO-repo-install-test"

FEED="${FEED:-nightly}"
PROJ="${PROJ:-osmocom:$FEED}"
CONTAINER="$DISTRO-repo-install-test-$FEED"

if [ -z "$TESTS" ]; then
	TESTS="
		test_conflict
		install_repo_packages
		test_binaries
		services_check
	"
fi

if [ -z "$PROJ_CONFLICT" ]; then
	case "$FEED" in
		latest)
			PROJ_CONFLICT="osmocom:nightly"
			;;
		nightly)
			PROJ_CONFLICT="osmocom:latest"
			;;
		next)
			PROJ_CONFLICT="osmocom:nightly"
			;;
	esac
fi

# Try to run "systemctl status" 10 times, kill the container on failure
check_if_systemd_is_running() {
	for i in $(seq 1 10); do
		sleep 1
		if docker exec "$CONTAINER" systemctl status; then
			return
		fi
	done

	echo "ERROR: systemd is not running properly."
	docker container kill "$CONTAINER"
	exit 1
}

# Kill already running container
if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2> /dev/null)" = "true" ]; then
	docker container kill "$CONTAINER"
	sleep 1
fi

# Additional docker run arguments
args=""
if [ -n "$KEEP_CACHE" ]; then
	args="$args -e KEEP_CACHE=1"
	args="$args -v $OSMO_CI_DIR/_repo_install_test_cache/debian/apt:/var/cache/apt"
	args="$args -v $OSMO_CI_DIR/_repo_install_test_cache/centos/dnf:/var/cache/dnf"
fi

# Run the container
# * This does not output anything, for debugging add -it and remove &.
# * /run, /tmp, cgroups, SYS_ADMIN: needed for systemd
# * SYS_NICE: needed for changing CPUScheduling{Policy,Priority} (osmo-bts systemd service files)
docker run	--rm \
		-v "$OSMO_CI_DIR/scripts/repo-install-test:/repo-install-test:ro" \
		--name "$CONTAINER" \
		-e FEED="$FEED" \
		-e PROJ="$PROJ" \
		-e PROJ_CONFLICT="$PROJ_CONFLICT" \
		-e DISTRO="$DISTRO" \
		-e TESTS="$TESTS" \
		-e container=docker \
		--tmpfs /run \
		--tmpfs /run/lock \
		--tmpfs /tmp \
		-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
		--cap-add SYS_ADMIN \
		--cap-add SYS_NICE \
		$args \
		"$USER/$DISTRO-repo-install-test" \
		/lib/systemd/systemd &
check_if_systemd_is_running

# Run the test script
ret=0
if ! docker exec "$CONTAINER" /repo-install-test/run-inside-docker.sh; then
	ret=1
fi

# Interactive shell
if [ -n "$INTERACTIVE" ]; then
	docker exec -it "$CONTAINER" bash || true
fi

docker container kill "$CONTAINER"

exit $ret
