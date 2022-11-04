#!/bin/sh

# This script is run by debian installer using preseed/late_command
# directive, see preseed.cfg

# Setup console, remove timeout on boot.
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="console=ttyS0"/g; s/TIMEOUT=5/TIMEOUT=0/g' /etc/default/grub
update-grub

# Members of `sudo` group are not asked for password.
sed -i 's/%sudo\tALL=(ALL:ALL) ALL/%sudo\tALL=(ALL:ALL) NOPASSWD:ALL/g' /etc/sudoers

# Empty message of the day.
echo -n > /etc/motd

# Unpack postinst tarball.
tar -x -v -z -C/tmp -f /tmp/postinst.tar.gz

# Install SSH key for ggsn.
mkdir -m700 /home/ggsn/.ssh
cat /tmp/postinst/authorized_keys > /home/ggsn/.ssh/authorized_keys
chown -R ggsn:ggsn /home/ggsn/.ssh

# Install SSH key for root.
mkdir -m700 /root/.ssh
cat /tmp/postinst/authorized_keys > /root/.ssh/authorized_keys
chown -R root:root /root/.ssh

# Install misc packages required for building osmocom code
apt-get install -y --no-install-recommends \
	autoconf \
	autoconf-archive \
	autogen \
	automake \
	build-essential \
	gcc \
	git \
	libc-ares-dev \
	libgnutls28-dev \
	libncurses5-dev \
	libtalloc-dev \
	libreadline-dev \
	libsctp-dev \
	libtool \
	make \
	pkg-config
apt-get clean

# add osmocom:nightly feed + install libosmocore-dev
apt-key add /tmp/postinst/Release.key
echo "deb http://downloads.osmocom.org/packages/osmocom:/nightly/Debian_9.0/ ./" > /etc/apt/sources.list.d/osmocom-nightly.list
apt-get update
apt-get install -y --no-install-recommends \
	libosmocore-dev
apt-get clean

# Remove some non-essential packages.
DEBIAN_FRONTEND=noninteractive apt-get purge -y nano laptop-detect tasksel dictionaries-common emacsen-common iamerican ibritish ienglish-common ispell

# Set domain name in hosts file
#sed -i 's/127.0.1.1\t\([a-z]*\).*/127.0.1.1\t\1\.dp\-net\.com\t\1/' /etc/hosts

# Avoid using DHCP-server provided domain name.
#sed -i 's/#supersede.*/supersede domain-name "dp-net.com";/' /etc/dhcp/dhclient.conf

# check out sources we need from their respective repositories
cd /usr/local/src
git clone https://git.netfilter.org/libmnl
(cd libmnl && autoreconf -fi && ./configure && make && make install)
git clone https://gerrit.osmocom.org/libgtpnl
(cd libgtpnl && autoreconf -fi && ./configure && make && make install)
git clone https://gerrit.osmocom.org/osmo-ggsn
(cd osmo-ggsn && autoreconf -fi && ./configure --enable-gtp-linux && make && make install)
ldconfig
