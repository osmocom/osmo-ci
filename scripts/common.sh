#!/bin/sh
# Various functions and variables used in multiple osmo-ci shell scripts
OSMO_CI_DIR="$(realpath "$(dirname "$0")/..")"
OSMO_GIT_URL_GITEA="https://gitea.osmocom.org"
OSMO_GIT_URL_GERRIT="https://gerrit.osmocom.org"

# Osmocom repositories of which we want to build release tarballs automatically, and list the current versions at
# https://jenkins.osmocom.org/jenkins/job/Osmocom-list-commits/lastSuccessfulBuild/artifact/commits.txt
# List is ordered alphabetically.
OSMO_RELEASE_REPOS="
	libasn1c
	libosmo-abis
	libosmo-gprs
	libosmo-netif
	libosmo-pfcp
	libosmo-sccp
	libosmocore
	libsmpp34
	libusrp
	osmo-bsc
	osmo-bts
	osmo-cbc
	osmo-e1d
	osmo-gbproxy
	osmo-ggsn
	osmo-gsm-manuals
	osmo-hlr
	osmo-hnodeb
	osmo-hnbgw
	osmo-iuh
	osmo-mgw
	osmo-msc
	osmo-pcap
	osmo-pcu
	osmo-remsim
	osmo-sgsn
	osmo-sip-connector
	osmo-smlc
	osmo-sysmon
	osmo-trx
	osmo-uecups
	osmo-upf
	osmocom-bb
	simtrace2
"

OSMO_BRANCH_DOCKER_PLAYGROUND="${OSMO_BRANCH_DOCKER_PLAYGROUND:-master}"

# Print commit of HEAD for an Osmocom git repository, e.g.:
# "f90496f577e78944ce8db1aa5b900477c1e479b0"
# $1: repository
osmo_git_head_commit() {
	# git output:
	# f90496f577e78944ce8db1aa5b900477c1e479b0        HEAD
	local url ret
	url="$(osmo_git_clone_url "$1")"
	ret="$(git ls-remote "$url" HEAD)"
	ret="$(echo "$ret" | awk '{print $1}')"
	echo "$ret"
}

# Print last tags and related commits for an Osmocom git repository, e.g.:
# "ec798b89700dcca5c5b28edf1a1cd16ea311f30a        refs/tags/1.0.1"
# $1: Osmocom repository
# $2: amount of commit, tag pairs to print (default: 1, set to "all" to print all)
# $3: string to print when there are no tags (default: empty string)
osmo_git_last_commits_tags() {
	# git output:
	# ec798b89700dcca5c5b28edf1a1cd16ea311f30a        refs/tags/1.0.1
	# eab5f594b0a7cf50ad97b039f73beff42cc8312a        refs/tags/1.0.1^{}
	# ...
	# 41e7cf115d4148a9f34fcb863b68b2d5370e335d        refs/tags/1.3.1^{}
	# 8a9f12dc2f69bf3a4e861cc9a81b71bdc5f13180        refs/tags/3G_2016_09
	# ee618ecbedec82dfd240334bc87d0d1c806477b0        refs/tags/debian/0.9.13-0_jrsantos.1
	# a3fdd24af099b449c9856422eb099fb45a5595df        refs/tags/debian/0.9.13-0_jrsantos.1^{}
	# ...
	local project="$1"
	local amount="$2"
	local default_str="$3"
	local url ret pattern

	case "$project" in
	strongswan-epdg)
		pattern='refs/tags/osmo-epdg-[0-9.]*$'
		;;
	gapk|osmo-fl2k|rtl-sdr)
		pattern='refs/tags/v[0-9.]*$'
		;;
	*)
		pattern='refs/tags/[0-9.]*$'
		;;
	esac

	url="$(osmo_git_clone_url "$project")"
	ret="$(git ls-remote --tags "$url")"
	ret="$(echo "$ret" | grep "$pattern" || true)"
	ret="$(echo "$ret" | sort -V -t/ -k3)"
	if [ "$amount" != "all" ]; then
		ret="$(echo "$ret" | tail -n "$amount")"
	fi

	if [ -n "$ret" ]; then
		echo "$ret"
	else
		echo "$default_str"
	fi
}

# Print last commits for an Osmocom git repository, e.g.:
# "ec798b89700dcca5c5b28edf1a1cd16ea311f30a"
# $1: repository
# $2: amount of commits to print (default: 1)
# $3: string to print when there are no tags (default: empty string)
osmo_git_last_commits() {
	ret="$(osmo_git_last_commits_tags "$1" "$2" "$3")"
	echo "$ret" | awk '{print $1}'
}

# Print last tags for an Osmocom git repository, e.g.:
# "1.0.1"
# $1: repository
# $2: amount of commits to print (default: 1)
# $3: string to print when there are no tags (default: empty string)
osmo_git_last_tags() {
	ret="$(osmo_git_last_commits_tags "$1" "$2" "$3")"
	echo "$ret" | cut -d/ -f 3
}

# Echo git clone URL for an Osmocom git repository. For projects developed on
# gerrit, use the gerrit URL to avoid the mirror sync delay, for other
# repositories use the gitea URL.
# https://osmocom.org/projects/cellular-infrastructure/wiki/Git_infrastructure
# $1: Osmocom project (e.g. "osmo-hlr")
osmo_git_clone_url() {
	case "$1" in
		rtl-sdr|osmo-fl2k|libosmo-dsp)
			echo "$OSMO_GIT_URL_GITEA"/sdr/"$1"
			;;
		osmo-gmr)
			echo "$OSMO_GIT_URL_GITEA"/satellite/"$1"
			;;
		osmo-isdntap)
			echo "$OSMO_GIT_URL_GITEA"/retronetworking/"$1"
			;;
		strongswan-epdg)
			echo "$OSMO_GIT_URL_GITEA"/ims-volte-vowifi/strongswan
			;;
		osmo_dia2gsup|osmo-epdg|osmo-s1gw)
			echo "$OSMO_GIT_URL_GERRIT"/erlang/"$1"
			;;
		*)
			echo "$OSMO_GIT_URL_GERRIT"/"$1"
			;;
	esac
}

# Print the subdirectory of the repository where the source lies (configure.ac etc.).
# Print nothing when the source is in the topdir of the repository.
osmo_source_subdir() {
	case "$1" in
		openbsc)
			echo "openbsc"
			;;
		simtrace2)
			echo "host"
			;;
	esac
}

# Build docker images from docker-playground.git.
# $1...$n: docker image names (e.g. "debian-stretch-build")
docker_images_require() {
	local oldpwd="$PWD"

	if [ -L "_docker_playground" ]; then
		echo "NOTE: _docker_playground is a symlink, skipping fetch, checkout, reset"
		cd "_docker_playground/$1"
	else
		# Get docker-plaground.git
		if [ -d "_docker_playground" ]; then
			git -C _docker_playground fetch
		else
			git clone https://gerrit.osmocom.org/docker-playground/ _docker_playground
		fi

		cd _docker_playground
		git checkout "$OSMO_BRANCH_DOCKER_PLAYGROUND"
		git reset --hard "origin/$OSMO_BRANCH_DOCKER_PLAYGROUND"

		# jenkins-common.sh expects to run from a subdir in docker-playground.git
		cd "$1"
	fi

	# Subshell: run docker_images_require from jenkins-common.sh, pass all arguments
	(. ../jenkins-common.sh; docker_images_require "$@")
	ret=$?
	cd "$oldpwd"
	return $ret
}

# Abort the script if required programs are missing
# $1...$n: program name
osmo_cmd_require() {
	local fail=0
	for i in "$@"; do
		if ! command -v "$i" >/dev/null 2>&1; then
			echo "Required program not found: $i"
			fail=1
		fi
	done
	if [ "$fail" = 1 ]; then
		exit 1
	fi
}
