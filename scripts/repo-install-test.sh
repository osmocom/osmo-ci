#!/bin/sh -ex
# Environment variables:
# * DOMAIN: default is downloads.osmocom.org, set to people.osmocom.org for testing pkgs from home:…
# * FEED: binary package feed (e.g. "latest", "nightly")
# * INTERACTIVE: set to 1 to keep an interactive shell open after the script ran (for debugging)
# * KEEP_VM: for development: don't kill/start VM if still running
# * PROJ: OBS project namespace (e.g. "osmocom:latest")
# * PROJ_CONFLICT: Conflicting OBS project namespace (e.g. "osmocom:nightly")
# * SKIP_PREPARE_VM: for development, skip the prepare_vm code
# * TESTS: which tests to run (all by default, see below for possible values)
. "$(dirname "$0")/common.sh"

DOMAIN="${DOMAIN:-downloads.osmocom.org}"
DISTRO="$1"
DISTROS="
	centos8
	debian10
	debian11
	debian12
"
IMG_DIR="/opt/qemu"
TEST_DIR="scripts/repo-install-test"
IMG_PATH="_repo_install_test_data/temp.qcow2"
PID_FILE="_repo_install_test_data/qemu.pid"
PORT_FILE="_repo_install_test_data/qemu.port"
LOG_FILE="_repo_install_test_data/qemu.log"

check_usage() {
	local i
	for i in $DISTROS; do
		if [ "$DISTRO" = "$i" ]; then
			return
		fi
	done
	set +x
	echo
	echo "usage: repo-install-test.sh DISTRO"
	echo "DISTRO: one of: $DISTROS"
	exit 1
}

get_backing_img_path() {
	local ret=""

	case "$DISTRO" in
	centos8)
		ret="$IMG_DIR/alma-8.5.qcow2"
		;;
	debian10)
		ret="$IMG_DIR/debian-10.qcow2"
		;;
	debian11)
		ret="$IMG_DIR/debian-11.qcow2"
		;;
	debian12)
		ret="$IMG_DIR/debian-12.qcow2"
		;;
	*)
		set +x
		echo "ERROR: script error, missing img path for $DISTRO" >&2
		exit 1
		;;
	esac

	if [ -e "$ret" ]; then
		echo "$ret"
	else
		set +x
		echo "ERROR: file not found: $ret" >&2
		echo "ERROR: qemu images not installed via ansible?" >&2
		exit 1
	fi
}

find_free_ssh_port() {
	SSH_PORT="$(echo "($PPID % 1000) + 22022" | bc)"
	while nc -z 127.0.0.1 "$SSH_PORT"; do
		SSH_PORT=$((SSH_PORT + 1))
	done

	echo "$SSH_PORT" > "$PORT_FILE"
}

prepare_img() {
	mkdir -p "$(dirname "$IMG_PATH")"

	qemu-img \
		create \
		-f qcow2 \
		-b "$(get_backing_img_path)" \
		-F qcow2 \
		"$IMG_PATH"
}

qemu_start() {
	if [ -n "$KEEP_VM" ] && [ -e "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")"; then
		SSH_PORT="$(cat "$PORT_FILE")"
		return
	fi

	prepare_img
	find_free_ssh_port

	(timeout 1h qemu-system-x86_64 \
		-cpu host \
		-device "virtio-net-pci,netdev=net" \
		-display none \
		-drive "file=$IMG_PATH,format=qcow2" \
		-enable-kvm \
		-m 1024 \
		-netdev "user,id=net,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22" \
		-nodefaults \
		-pidfile "$PID_FILE" \
		-serial stdio \
		-smp 16 >"$LOG_FILE" 2>&1) &
}

qemu_ssh() {
	timeout "${TIMEOUT:-1m}" \
		sshpass -p root \
		ssh \
			-p "$SSH_PORT" \
			-o StrictHostKeyChecking=no \
			-o UserKnownHostsFile=/dev/null \
			root@127.0.0.1 \
			-- \
			"$@"
}

qemu_scp() {
	timeout "${TIMEOUT:-1m}" \
		sshpass -p root \
		scp \
			-P "$SSH_PORT" \
			-o StrictHostKeyChecking=no \
			-o UserKnownHostsFile=/dev/null \
			"$@"
}

qemu_prepare_vm() {
	case "$DISTRO" in
	centos8)
		# https://almalinux.org/blog/2023-12-20-almalinux-8-key-update/
		qemu_ssh dnf upgrade -y almalinux-release
		;;
	esac
}

qemu_run_test_script() {
	cat <<- EOF > "$TEST_DIR/run-inside-env.sh"
	#!/bin/sh -ex

	export DISTRO="$DISTRO"
	export DOMAIN="$DOMAIN"
	export FEED="$FEED"
	export PROJ="$PROJ"
	export PROJ_CONFLICT="$PROJ_CONFLICT"
	export SKIP_PREPARE_VM="$SKIP_PREPARE_VM"
	export TESTS="$TESTS"

	/repo-install-test/run-inside.sh
	EOF

	qemu_ssh rm -rf /repo-install-test/
	qemu_ssh mkdir /repo-install-test
	qemu_scp -r "$TEST_DIR"/* "root@127.0.0.1:/repo-install-test"

	TIMEOUT="1h" qemu_ssh sh -ex /repo-install-test/run-inside-env.sh
}

qemu_print_log() {
	echo
	echo "Contents of $LOG_FILE:"
	echo
	cat "$LOG_FILE"
}

qemu_ssh_wait() {
	set +x
	echo
	echo "Waiting for VM to boot up..."
	echo
	set -x

	# PID file does not get created immediately
	sleep 1
	local pid="$(cat "$PID_FILE")"

	for i in $(seq 1 6); do
		if [ -z "$pid" ] || ! kill -0 "$pid"; then
			set +x
			echo "ERROR: qemu failed, pid: $pid"
			qemu_print_log
			exit 1
		fi

		if TIMEOUT=10s qemu_ssh true; then
			return
		fi

		sleep 1
	done

	set +x
	echo "ERROR: timeout, VM did not boot up. Log file contents:"
	qemu_print_log
	exit 1
}

clean_up() {
	if [ -n "$KEEP_VM" ]; then
		return
	fi

	if [ -e "$PID_FILE" ]; then
		kill $(cat "$PID_FILE") || true
	fi

	rm -f "$IMG_PATH"
}

clean_up_trap() {
	if [ -n "$INTERACTIVE" ]; then
		TIMEOUT="1h" qemu_ssh bash -i
	fi

	set +x
	echo
	echo "### Clean up ###"
	echo
	set -x

	trap - EXIT INT TERM 0

	clean_up
}

check_usage

FEED="${FEED:-nightly}"
PROJ="${PROJ:-osmocom:$FEED}"

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


clean_up
trap clean_up_trap EXIT INT TERM 0

qemu_start
qemu_ssh_wait


set +x
echo
echo "VM is running!"
echo
set -x

qemu_prepare_vm
qemu_run_test_script
