#!/bin/sh -ex
# Environment variables:
# * DISTRO: linux distribution  name (e.g. "centos8")
# * FEED: binary package feed (e.g. "latest", "nightly")
# * KEEP_CACHE: set to 1 to keep downloaded binary packages (for development)
# * PROJ: OBS project namespace (e.g. "osmocom:latest")
# * PROJ_CONFLICT: Conflicting OBS project namespace (e.g. "osmocom:nightly")
# * SKIP_PREPARE_VM: for development, skip the prepare_vm code
# * TESTS: which tests to run (see repo-install-test.sh)

# Systemd services that must start up successfully after installing all packages (OS#3369)
# Disabled services:
# * osmo-ctrl2cgi (missing config: /etc/osmocom/ctrl2cgi.ini, OS#4108)
# * osmo-e1d (missing config, OS#5817)
# * osmo-ggsn (conflicting config, OS#5817)
# * osmo-remsim-client (exits immediately without USB device)
# * osmo-trap2cgi (missing config: /etc/osmocom/%N.ini, OS#4108)
# * osmo-trx-* (exits immediately without trx device)
# * osmo-upf (not available for debian 10, gets added in services_check())
SERVICES="
	osmo-bsc
	osmo-bts-virtual
	osmo-cbc
	osmo-gbproxy
	osmo-gtphub
	osmo-hlr
	osmo-hnbgw
	osmo-hnodeb
	osmo-mgw
	osmo-msc
	osmo-pcap-client
	osmo-pcap-server
	osmo-pcu
	osmo-remsim-bankd
	osmo-remsim-server
	osmo-sgsn
	osmo-sip-connector
	osmo-smlc
	osmo-stp
"
# Services working in nightly, but not yet in latest
SERVICES_NIGHTLY="
	osmo-bsc-nat
"

distro_obsdir() {
	case "$DISTRO" in
		centos8)
			echo "CentOS_8"
			;;
		debian10)
			echo "Debian_10"
			;;
		debian11)
			echo "Debian_11"
			;;
		*)
			echo "ERROR: unknown obsdir for '$DISTRO'." >&2
			exit 1
			;;
	esac
}

DISTRO_OBSDIR="$(distro_obsdir)"

# $1: OBS project (e.g. "osmocom:nightly" -> "osmocom:/nightly")
proj_with_slashes() {
	echo "$1" | sed "s.:.:/.g"
}

# $1: OBS project (e.g. "osmocom:nightly" -> "osmocom_nightly")
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
	if [ -n "$PROJ_CONFLICT" ]; then
		echo "Checking conflicting project: $PROJ_CONFLICT"
	else
		echo "ERROR: missing environment variable \$PROJ_CONFLICT!"
		exit 1
	fi
	if [ -n "$DISTRO" ]; then
		echo "Linux distribution: $DISTRO"
	else
		echo "ERROR: missing environment variable \$DISTRO!"
		exit 1
	fi
	if [ -n "$TESTS" ]; then
		echo "Enabled tests: $TESTS"
	else
		echo "ERROR: missing environment variable \$TESTS!"
	fi
}

# $1: OBS project (e.g. "osmocom:nightly")
configure_osmocom_repo_debian() {
	local proj="$1"
	local obs_repo="downloads.osmocom.org/packages/$(proj_with_slashes "$proj")/$DISTRO_OBSDIR/"

	echo "Configuring Osmocom repository"

	# Add repository key
	if ! [ -e /tmp/Release.key ]; then
		wget -O /tmp/Release.key "https://obs.osmocom.org/projects/$proj/public_key"
	fi

	apt-key add /tmp/Release.key

	echo "deb http://$obs_repo ./" > "/etc/apt/sources.list.d/$proj.list"
	apt-get update
}

# $1: OBS project (e.g. "osmocom:nightly")
configure_osmocom_repo_debian_remove() {
	local proj="$1"
	rm "/etc/apt/sources.list.d/$proj.list"
}

# $1: OBS project (e.g. "osmocom:nightly")
configure_osmocom_repo_centos() {
	local proj="$1"
	local baseurl="https://downloads.osmocom.org/packages/$(proj_with_slashes "$proj")/$DISTRO_OBSDIR"

	echo "Configuring Osmocom repository"
	# Generate this file, based on the feed:
	# https://downloads.osmocom.org/packages/osmocom:/latest/CentOS_8/osmocom:latest.repo
	cat << EOF > "/etc/yum.repos.d/$proj.repo"
[$(proj_with_underscore "$proj")]
name=$proj
type=rpm-md
baseurl=$baseurl/
gpgcheck=1
gpgkey=$baseurl/repodata/repomd.xml.key
enabled=1
EOF
}

# $1: OBS project (e.g. "osmocom:nightly")
configure_osmocom_repo_centos_remove() {
	local proj="$1"
	rm "/etc/yum.repos.d/$proj.repo"
}

# $1: OBS project (e.g. "osmocom:nightly")
configure_osmocom_repo() {
	case "$DISTRO" in
		debian*)
			configure_osmocom_repo_debian "$@"
			;;
		centos*)
			configure_osmocom_repo_centos "$@"
			;;
	esac
}

prepare_vm_debian() {
	# fmtutil fails in tex-common postinst script. This gets installed as
	# dependency of osmo-gsm-manuals-dev, but is completely unrelated to
	# what we want to test here so just stub it out.
	ln -sf /bin/true /usr/bin/fmtutil
	echo "path-exclude=/usr/bin/fmtutil" >> /etc/dpkg/dpkg.cfg.d/stub

	apt-get update --allow-releaseinfo-change
	apt-get install -y --no-install-recommends \
		aptitude \
		ca-certificates \
		gnupg2 \
		wget

	case "$DISTRO" in
		debian10)
			# Can't access https://osmocom.org otherwise
			apt-get install -y --no-install-recommends \
				libgnutls30
		;;
	esac
}

prepare_vm_centos() {
	# Install dnf-utils for repoquery
	dnf install -y dnf-utils

	# Make additional development libraries available
	yum config-manager --set-enabled powertools
}

prepare_vm() {
	if [ -n "$SKIP_PREPARE_VM" ]; then
		return
	fi

	case "$DISTRO" in
		debian*)
			prepare_vm_debian
			;;
		centos*)
			prepare_vm_centos
			;;
	esac

	configure_osmocom_repo "$PROJ"
}

# $1: file
# $2-n: patterns to look for in file with grep
find_patterns_or_exit() {
	local file="$1"
	local pattern
	shift

	for pattern in "$@"; do
		if grep -q "$pattern" "$file"; then
			continue
		fi

		echo "ERROR: could not find pattern '$pattern' in file '$file'!"
		exit 1
	done
}

test_conflict_debian() {
	apt-get -y install libosmocore

	configure_osmocom_repo_debian_remove "$PROJ"
	configure_osmocom_repo_debian "$PROJ_CONFLICT"

	(apt-get -y install osmo-mgw 2>&1 && touch /tmp/fail) | tee /tmp/out

	if [ -e /tmp/fail ]; then
		echo "ERROR: unexpected exit 0!"
		exit 1
	fi

	find_patterns_or_exit \
		/tmp/out \
		"requested an impossible situation" \
		"^The following packages have unmet dependencies:"

	case "$DISTRO" in
		debian10)
			find_patterns_or_exit \
				/tmp/out \
				"Depends: osmocom-" \
				"but it is not going to be installed"
			;;
		debian11)
			find_patterns_or_exit \
				/tmp/out \
				"Conflicts: osmocom-"
			;;
	esac

	configure_osmocom_repo_debian_remove "$PROJ_CONFLICT"
	configure_osmocom_repo_debian "$PROJ"
}

test_conflict_centos() {
	dnf -y install libosmocore-devel

	configure_osmocom_repo_centos_remove "$PROJ"
	configure_osmocom_repo_centos "$PROJ_CONFLICT"

	(dnf -y install osmo-mgw 2>&1 && touch /tmp/fail) | tee /tmp/out

	if [ -e /tmp/fail ]; then
		echo "ERROR: unexpected exit 0!"
		exit 1
	fi

	find_patterns_or_exit \
		/tmp/out \
		"^Error:" \
		"but none of the providers can be installed" \
		"conflicts with osmocom-"

	configure_osmocom_repo_centos_remove "$PROJ_CONFLICT"
	configure_osmocom_repo_centos "$PROJ"
}

test_conflict() {
	case "$DISTRO" in
		debian*)
			test_conflict_debian
			;;
		centos*)
			test_conflict_centos
			;;
	esac
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
	echo "Installing all repository packages"

	# Get a list of all packages from the repository. Reference:
	# https://www.debian.org/doc/manuals/aptitude/ch02s04s05.en.html
	aptitude search -F%p \
		"?origin(.*$PROJ.*) ?architecture(native)" | sort \
		> osmocom_packages_all.txt

	filter_packages_txt
	apt install -y $(cat osmocom_packages.txt)
}

install_repo_packages_centos() {
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

install_repo_packages() {
	case "$DISTRO" in
		debian*)
			install_repo_packages_debian
			;;
		centos*)
			install_repo_packages_centos
			;;
	esac
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
		osmo-hnodeb \
		osmo-mgw \
		osmo-msc \
		osmo-pcu \
		osmo-sgsn \
		osmo-sip-connector \
		osmo-stp \
		osmo-trx-uhd

	case "$DISTRO" in
	debian*)
		test_binaries_version \
			osmo-trx-usrp1
		;;
	esac
}

services_check() {
	local service
	local services_feed="$SERVICES"
	local failed=""

	if [ "$FEED" = "nightly" ]; then
		services_feed="$services_feed $SERVICES_NIGHTLY"
	fi

	# We don't build osmo-upf for debian 10
	if [ "$DISTRO" != "debian10" ]; then
		# osmo-upf <= 0.1.1 needs GTP kernel module
		if [ "$FEED" = "nightly" ]; then
			services_feed="$services_feed osmo-upf"
		fi
	fi

	# OS#5817: osmo-ggsn conflicts with osmo-gtphub; explicitly stop it
	# here until it is fixed, as it gets auto-started after installation
	systemctl stop osmo-ggsn

	systemctl start $services_feed
	sleep 2

	for service in $services_feed; do
		if ! systemctl --no-pager -l -n 200 status $service; then
			failed="$failed $service"
			journalctl -u "$service" -n 200
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
prepare_vm

for test in $TESTS; do
	set +x
	echo
	echo "### Running test: $test ###"
	echo
	set -x

	case "$test" in
		test_conflict)
			test_conflict
			;;
		install_repo_packages)
			install_repo_packages
			;;
		test_binaries)
			# install_repo_packages must run first!
			test_binaries
			;;
		services_check)
			# install_repo_packages must run first!
			services_check
			;;
		*)
			echo "ERROR: unknown test: $test"
			exit 1
			;;
	esac

	set +x
	echo
	echo "### Test successful: $test ###"
	echo
	set -x
done