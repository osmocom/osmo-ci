#!/bin/sh -ex
# Environment variables:
# * FEED: binary package feed (e.g. "latest", "nightly")
# * PROJ: OBS project namespace (e.g. "network:osmocom:latest")
# * KEEP_CACHE: set to 1 to keep downloaded binary packages (for development)
# * DISTRO: linux distribution  name (e.g. "debian", "centos")

# Systemd services that must start up successfully after installing all packages (OS#3369)
# Disabled services:
# * osmo-ctrl2cgi (missing config: /etc/osmocom/ctrl2cgi.ini, OS#4108)
# * osmo-trap2cgi (missing config: /etc/osmocom/%N.ini, OS#4108)
# * osmo-ggsn (no tun device in docker)
SERVICES="
	osmo-bsc
	osmo-gbproxy
	osmo-gtphub
	osmo-hlr
	osmo-mgw
	osmo-msc
	osmo-pcap-client
	osmo-sip-connector
	osmo-stp
"
# Services working in nightly, but not yet in latest
# * osmo-pcap-server: service not included in osmo-pcap 0.0.11
# * osmo-sgsn: conflicts with osmo-gtphub config in osmo-sgsn 1.4.0
# * osmo-pcu: needs osmo-bts-virtual to start up properly
# * osmo-hnbgw: tries to listen on 10.23.24.1 in osmo-iuh 0.4.0
# * osmo-bts-virtual: unit id not matching osmo-bsc's config in osmo-bsc 1.4.0
SERVICES_NIGHTLY="
	osmo-pcap-server
	osmo-sgsn
	osmo-pcu
	osmo-hnbgw
	osmo-bts-virtual
"

# $1: OBS project (e.g. "network:osmocom:nightly" -> "network:/osmocom:/nightly")
proj_with_slashes() {
	echo "$1" | sed "s.:.:/.g"
}

# $1: OBS project (e.g. "network:osmocom:nightly" -> "network_osmocom_nightly")
proj_with_underscore() {
	echo "$1" | tr : _
}

check_env() {
	if [ -n "$FEED" ]; then
		echo "Checking feed: $FEED"
	else
		echo "ERROR: missing environment variable \$FEED!"
		exit 1
	fi
	if [ -n "$PROJ" ]; then
		echo "Checking project: $PROJ"
	else
		echo "ERROR: missing environment variable \$PROJ!"
		exit 1
	fi
	if [ -n "$DISTRO" ]; then
		echo "Linux distribution: $DISTRO"
	else
		echo "ERROR: missing environment variable \$DISTRO!"
		exit 1
	fi
}

configure_osmocom_repo_debian() {
	local http="http://download.opensuse.org/repositories/$(proj_with_slashes "$PROJ")/Debian_9.0/"

	echo "Configuring Osmocom repository"
	echo "deb $http ./" \
		> /etc/apt/sources.list.d/osmocom-latest.list
	apt-get update
}

configure_osmocom_repo_centos8() {
	local baseurl="https://download.opensuse.org/repositories/$(proj_with_slashes "$PROJ")/CentOS_8"

	echo "Configuring Osmocom repository"
	# Generate this file, based on the feed:
	# https://download.opensuse.org/repositories/network:osmocom:latest/CentOS_8/network:osmocom:latest.repo
	cat << EOF > "/etc/yum.repos.d/$PROJ.repo"
[$(proj_with_underscore "$PROJ")]
name=$FEED packages of the Osmocom project (CentOS_8)
type=rpm-md
baseurl=$baseurl/
gpgcheck=1
gpgkey=$baseurl/repodata/repomd.xml.key
enabled=1
EOF
}

configure_keep_cache_debian() {
	if [ -z "$KEEP_CACHE" ]; then
		return
	fi

	rm /etc/apt/apt.conf.d/docker-clean

	# "apt" will actually remove the cache by default, even if "apt-get" keeps it.
	# https://unix.stackexchange.com/a/447607
	echo "Binary::apt::APT::Keep-Downloaded-Packages "true";" \
		> /etc/apt/apt.conf.d/01keep-debs
}

configure_keep_cache_centos8() {
	if [ -z "$KEEP_CACHE" ]; then
		return
	fi
	echo "keepcache=1" >> /etc/dnf/dnf.conf
}

# Filter $PWD/osmocom_packages_all.txt through a blacklist_$DISTRO.txt and store the result in
# $PWD/osmocom_packages.txt.
filter_packages_txt() {
	# Copy distro specific blacklist file, remove comments and sort it
	grep -v "^#" /repo-install-test/blacklist_$DISTRO.txt | sort -u > blacklist.txt

	# Generate list of pkgs to be installed from available pkgs minus the ones blacklisted
	comm -23 osmocom_packages_all.txt \
		blacklist.txt > osmocom_packages.txt
}

install_repo_packages_debian() {
	local obs="obs://build.opensuse.org/$PROJ/Debian_9.0"

	echo "Installing all repository packages"

	# Get a list of all packages from the repository. Reference:
	# https://www.debian.org/doc/manuals/aptitude/ch02s04s05.en.html
	aptitude search -F%p \
		"?origin($obs) ?architecture(native)" | sort \
		> osmocom_packages_all.txt

	filter_packages_txt
	apt install -y $(cat osmocom_packages.txt)
}

install_repo_packages_centos8() {
	echo "Installing all repository packages"

	# Get a list of all packages from the repository
	LANG=C.UTF-8 repoquery \
		--quiet \
		--repoid="$(proj_with_underscore "$PROJ")" \
		--archlist="x86_64,noarch" \
		--qf="%{name}" \
		> osmocom_packages_all.txt

	filter_packages_txt
	dnf install -y $(cat osmocom_packages.txt)
}

test_binaries_version() {
	# Make sure --version runs and does not output UNKNOWN
	failed=""
	for program in $@; do
		# Make sure it runs at all
		$program --version

		# Check for UNKNOWN
		if $program --version | grep -q UNKNOWN; then
			failed="$failed $program"
			echo "ERROR: this program prints UNKNOWN in --version!"
		fi
	done

	if [ -n "$failed" ]; then
		echo "ERROR: the following program(s) print UNKNOWN in --version:"
		echo "$failed"
		return 1
	fi
}

test_binaries() {
	# Make sure that binares run at all and output a proper version
	test_binaries_version \
		osmo-bsc \
		osmo-bts-trx \
		osmo-bts-virtual \
		osmo-gbproxy \
		osmo-gtphub \
		osmo-ggsn \
		osmo-hlr \
		osmo-hlr-db-tool \
		osmo-hnbgw \
		osmo-mgw \
		osmo-msc \
		osmo-pcu \
		osmo-sgsn \
		osmo-sip-connector \
		osmo-stp \
		osmo-trx-uhd

	if [ "$DISTRO" = "debian" ]; then
		test_binaries_version \
			osmo-trx-usrp1
	fi
}

services_check() {
	local service
	local services_feed="$SERVICES"
	local failed=""

	if [ "$FEED" = "nightly" ]; then
		services_feed="$services_feed $SERVICES_NIGHTLY"
	fi

	systemctl start $services_feed
	sleep 2

	for service in $services_feed; do
		if ! systemctl --no-pager -l -n 200 status $service; then
			failed="$failed $service"
		fi
	done

	systemctl stop $services_feed

	if [ -n "$failed" ]; then
		set +x
		echo
		echo "ERROR: services failed to start: $failed"
		echo
		exit 1
	fi
}

check_env
configure_keep_cache_${DISTRO}
configure_osmocom_repo_${DISTRO}
install_repo_packages_${DISTRO}
test_binaries
services_check
