#!/bin/sh -e
# Create qcow2 images with ssh root login enabled for repo-install-test and
# store them in /opt/qemu.
# Set KEEP_CACHE=1 during development, so virt-builder only needs to download
# the image once.

# Distribution names, as in the base images from here:
# https://builder.libguestfs.org/
DISTROS="
	alma-8.5
	debian-10
	debian-11
"
TEMP_SCRIPT="$(mktemp)"

if [ "$(id -u)" != 0 ]; then
	echo "ERROR: run this as root"
	exit 1
fi

mkdir -p /opt/qemu

for distro in $DISTROS; do
	img="/opt/qemu/$distro.qcow2"

	echo
	echo "# $distro"
	echo

	if [ -e "$img" ]; then
		echo "=> File exists, skipping."
		continue
	fi

	case "$distro" in
	alma-*)
		# Install SCTP kernel module
		# https://forums.centos.org/viewtopic.php?t=71818
		cat <<- EOF > "$TEMP_SCRIPT"
		#!/bin/sh -ex
		dnf upgrade -y kernel
		dnf install -y kernel-modules-extra
		rm -f /etc/modprobe.d/sctp-blacklist.conf
		EOF
		;;
	debian-*)
		# Generate SSH server keys and allow login as root
		cat <<- EOF > "$TEMP_SCRIPT"
		#!/bin/sh -ex
		ssh-keygen -A
		echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
		EOF
		;;
	esac

	virt-builder \
		"$distro" \
		-o "/opt/qemu/$distro.qcow2" \
		--format qcow2 \
		--root-password password:root \
		--run "$TEMP_SCRIPT" \
		--verbose

	if [ -z "$KEEP_CACHE" ]; then
		virt-builder --delete-cache
	fi
done

rm "$TEMP_SCRIPT"

# Marker for ansible main.yml to skipt the script
touch /opt/qemu/.qemu-create-vms-done-v1

echo
echo "Done!"
