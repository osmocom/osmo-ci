#!/bin/sh -e
. "$(dirname "$0")/../common.sh"
OSMO_CI_DIR="$(realpath $(dirname "$0")/../..)"
TEMP="$OSMO_CI_DIR/_temp_manuals"
WEB_PATH="/downloads/home/docs/web-files"
SSH_COMMAND="ssh -o UserKnownHostsFile=$TEMP/src/osmo-gsm-manuals/build/known_hosts -p 48"
DOCKER_IMAGE="$USER/debian-bookworm-build"
LOG_PREFIX="::"

# Releases that were made before shared osmo-gsm-manuals, or where build fails
# for other reasons.
TAGS_IGNORE="
	openbsc:0.9.0,
	openbsc:0.9.1,
	openbsc:0.9.2,
	openbsc:0.9.3,
	openbsc:0.9.4,
	openbsc:0.9.5,
	openbsc:0.9.6,
	openbsc:0.9.8,
	openbsc:0.9.9,
	openbsc:0.9.10,
	openbsc:0.9.11,
	openbsc:0.9.12,
	openbsc:0.9.13,
	openbsc:0.9.14,
	openbsc:0.9.15,
	openbsc:0.9.16,
	openbsc:0.10.0,
	openbsc:0.10.1,
	openbsc:0.11.0,
	openbsc:0.12.0,
	openbsc:0.13.0,
	openbsc:0.14.0,
	openbsc:0.15.0,
	openbsc:1.0.0,
	openbsc:1.1.0,

	osmo-bsc:1.0.1,
	osmo-bsc:1.1.0,
	osmo-bsc:1.1.1,
	osmo-bsc:1.1.2,
	osmo-bsc:1.2.0,
	osmo-bsc:1.2.1,
	osmo-bsc:1.2.2,
	osmo-bsc:1.3.0,
	osmo-bsc:1.4.0,
	osmo-bsc:1.4.1,
	osmo-bsc:1.5.0,
	osmo-bsc:1.6.0,

	osmo-bts:0.0.1,
	osmo-bts:0.1.0,
	osmo-bts:0.2.0,
	osmo-bts:0.3.0,
	osmo-bts:0.4.0,
	osmo-bts:0.6.0,
	osmo-bts:0.7.0,
	osmo-bts:0.8.0,
	osmo-bts:0.8.1,
	osmo-bts:1.0.0,
	osmo-bts:1.0.1,
	osmo-bts:1.1.0,
	osmo-bts:1.2.0,

	osmo-e1d:0.0.1,
	osmo-e1d:0.1.0,
	osmo-e1d:0.1.1,
	osmo-e1d:0.2.0,
	osmo-e1d:0.2.1,
	osmo-e1d:0.2.2,
	osmo-e1d:0.3.0,
	osmo-e1d:0.4.0,

	osmo-ggsn:1.0.0,
	osmo-ggsn:1.1.0,
	osmo-ggsn:1.2.0,
	osmo-ggsn:1.2.1,
	osmo-ggsn:1.2.2,

	osmo-gsm-tester:0.1,

	osmo-hlr:0.0.1,
	osmo-hlr:0.1.0,
	osmo-hlr:0.2.0,
	osmo-hlr:0.2.1,

	osmo-mgw:1.0.1,
	osmo-mgw:1.0.2,
	osmo-mgw:1.1.0,
	osmo-mgw:1.2.0,
	osmo-mgw:1.2.1,
	osmo-mgw:1.3.0,
	osmo-mgw:1.4.0,

	osmo-msc:1.0.1,
	osmo-msc:1.1.0,
	osmo-msc:1.1.1,
	osmo-msc:1.1.2,
	osmo-msc:1.2.0,
	osmo-msc:1.3.0,
	osmo-msc:1.3.1,
	osmo-msc:1.4.0,
	osmo-msc:1.5.0,
	osmo-msc:1.6.0,
	osmo-msc:1.6.1,
	osmo-msc:1.6.2,
	osmo-msc:1.6.3,

	osmo-pcap:0.0.1,
	osmo-pcap:0.0.2,
	osmo-pcap:0.0.3,
	osmo-pcap:0.0.4,
	osmo-pcap:0.0.5,
	osmo-pcap:0.0.6,
	osmo-pcap:0.0.7,
	osmo-pcap:0.0.8,
	osmo-pcap:0.0.9,
	osmo-pcap:0.0.10,
	osmo-pcap:0.0.11,
	osmo-pcap:0.1.0,
	osmo-pcap:0.1.1,
	osmo-pcap:0.1.2,
	osmo-pcap:0.1.3,

	osmo-pcu:0.1,
	osmo-pcu:0.1.0,
	osmo-pcu:0.2,
	osmo-pcu:0.2.0,
	osmo-pcu:0.4.0,
	osmo-pcu:0.5.0,
	osmo-pcu:0.5.1,

	osmo-remsim:0.0,
	osmo-remsim:0.1.0,
	osmo-remsim:0.2.0,
	osmo-remsim:0.2.1,

	osmo-sgsn:0.10.0,
	osmo-sgsn:0.10.1,
	osmo-sgsn:0.11.0,
	osmo-sgsn:0.12.0,
	osmo-sgsn:0.13.0,
	osmo-sgsn:0.14.0,
	osmo-sgsn:0.15.0,
	osmo-sgsn:0.9.0,
	osmo-sgsn:0.9.1,
	osmo-sgsn:0.9.10,
	osmo-sgsn:0.9.11,
	osmo-sgsn:0.9.12,
	osmo-sgsn:0.9.13,
	osmo-sgsn:0.9.13+deb1,
	osmo-sgsn:0.9.14,
	osmo-sgsn:0.9.14-onwaves1,
	osmo-sgsn:0.9.15,
	osmo-sgsn:0.9.16,
	osmo-sgsn:0.9.2,
	osmo-sgsn:0.9.3,
	osmo-sgsn:0.9.4,
	osmo-sgsn:0.9.5,
	osmo-sgsn:0.9.6,
	osmo-sgsn:0.9.8,
	osmo-sgsn:0.9.9,
	osmo-sgsn:1.0.1,
	osmo-sgsn:1.1.0,
	osmo-sgsn:1.10.0,
	osmo-sgsn:1.2.0,
	osmo-sgsn:1.3.0,
	osmo-sgsn:1.4.0,
	osmo-sgsn:1.4.1,
	osmo-sgsn:1.5.0,
	osmo-sgsn:1.6.0,
	osmo-sgsn:1.6.1,

	osmo-sip-connector:0.0.1,
	osmo-sip-connector:1.1.0,
	osmo-sip-connector:1.1.1,

	libosmo-sccp:0.0.1,
	libosmo-sccp:0.0.2,
	libosmo-sccp:0.0.3,
	libosmo-sccp:0.0.4,
	libosmo-sccp:0.0.5,
	libosmo-sccp:0.0.5.1,
	libosmo-sccp:0.0.6,
	libosmo-sccp:0.0.6.1,
	libosmo-sccp:0.0.6.2,
	libosmo-sccp:0.0.6.3,
	libosmo-sccp:0.10.0,
	libosmo-sccp:0.7.0,
	libosmo-sccp:0.8.0,
	libosmo-sccp:0.8.1,
	libosmo-sccp:0.9.0,
	libosmo-sccp:1.0.0,
	libosmo-sccp:1.1.0,
	libosmo-sccp:1.2.0,

	osmo-trx:0.2.0,
	osmo-trx:0.3.0,
	osmo-trx:0.4.0,

	pysim:1.0,

	pyosmocom:0.0.1,
	pyosmocom:0.0.2,
"

mkdir -p \
	"$TEMP" \
	"$TEMP/src"

check_ssh_auth_sock() {
	if [ -z "$SSH_AUTH_SOCK" ]; then
		echo "ERROR: SSH_AUTH_SOCK is not set"
		exit 1
	fi
}

# Additional configure options to use, so manuals include all VTY commands
# $1: repo name
get_configure_opts_from_repo_name() {
	case "$1" in
	osmo-hnbgw)
		echo "--enable-pfcp"
		;;
	osmo-msc|osmo-sgsn)
		echo "--enable-iu"
		;;
	esac
}

# $1: docs dir
get_repo_name_from_docs_dir() {
	case "$1" in
	osmo-stp)
		echo "libosmo-sccp"
		;;
	*)
		echo "$1"
		;;
	esac
}

# $1: repo name
get_docs_dir_from_repo_name() {
	case "$1" in
	libosmo-sccp)
		echo "osmo-stp"
		;;
	*)
		echo "$1"
		;;
	esac
}


# $1: path on server, e.g. "/docs/osmo-bsc"
get_server_ls() {
	local dir="$1"
	local out="$TEMP/ls$(echo "$dir" | tr / _)"

	echo "$LOG_PREFIX Listing files on server: $dir"

	if [ -e "$out" ]; then
		echo "Skipped, file exists: $out"
		return
	fi

	dir="$(echo "$dir" | sed "s.^/docs.$WEB_PATH.")"
	$SSH_COMMAND docs@ftp.osmocom.org "ls -1 $dir" >"$out"
}

# $1: repository
get_git_tags() {
	local repo="$1"
	local out="$TEMP/git_tags_$repo"

	echo "$LOG_PREFIX Getting git tags"

	if [ -e "$out" ]; then
		echo "Skipped, file exists: $out"
		return
	fi

	osmo_git_last_tags "$repo" "all" >"$out"
}

# $1: docs dir
# $2: tag
manuals_exist() {
	local docs_dir="$1"
	local tag="$2"

	grep -q "^$tag$" "$TEMP"/ls_docs_"$docs_dir"
}

# $1: repository
# $2: tag
is_tag_ignored() {
	local repo="$1"
	local tag="$2"

	case "$TAGS_IGNORE" in
	*"$repo:$tag,"*)
		return 0
		;;
	esac

	return 1
}

# $1: repository
# $2: tag
clone_repo() {
	local repo="$1"
	local tag="$2"
	local gitdir="$TEMP/src/$repo"

	if ! [ -d "$gitdir" ]; then
		local url="$(osmo_git_clone_url "$repo")"
		echo "$LOG_PREFIX Cloning $url"
		git -C "$TEMP/src" clone "$url" "$repo"
	fi

	echo "$LOG_PREFIX Checkout $tag"
	cd "$gitdir"
	git reset --hard HEAD
	git checkout "$tag"
	git submodule update --init
	git clean -dxf

	# Fix depends on packages that don't exist anymore
	sed -i 's/dh-systemd \(.*\),//g' debian/control
	sed -i 's/python-minimal,//g' debian/control
}

# $1: repository
# $2: tag
build_publish_manuals() {
	local repo="$1"
	local tag="$2"
	local configure_opts="--enable-manuals $(get_configure_opts_from_repo_name "$repo")"
	echo "$LOG_PREFIX Building manuals"

	if ! docker run \
		--rm \
		-e "BUILD_RELEASE=1" \
		-e "DEBIAN_FRONTEND=noninteractive" \
		-e "OSMO_GSM_MANUALS_DIR=/opt/osmo-gsm-manuals" \
		-e "OSMO_REPOSITORY=$(get_docs_dir_from_repo_name "$repo")" \
		-e "PUBLISH_REF=$tag" \
		-e "SSH_AUTH_SOCK=/ssh-agent" \
		-v "$OSMO_CI_DIR/scripts/manuals:/manuals" \
		-v "$TEMP/src/$repo/:/build" \
		-v $(readlink -f $SSH_AUTH_SOCK):/ssh-agent \
		"$DOCKER_IMAGE" \
		sh -ex -c "
			apt-get update

			# The docker image has the nightly repository
			# configured, in which packages can't be installed from
			# different build dates. Upgrade osmocom-nightly first
			# to prevent errors in apt-get build-dep below.
			apt-get -y upgrade osmocom-nightly

			# Install dependencies
			case $repo in
			*)
				apt-get -y build-dep /build
				;;
			esac

			# Remove DRAFT in osmo-gsm-manuals
			cd /opt/osmo-gsm-manuals/
			patch -p1 < /manuals/0001-build-custom-dblatex.sty-remove-DRAFT.patch

			# Build manuals
			cd /build
			case $repo in
			openbsc)
				for dir in manuals/*/; do
					su build -c \"make -C \$dir\"
				done
				;;
			osmo-epdg)
				su build -c \"make -C docs/manuals\"
				;;
			*)
				su build -c \"autoreconf -fi\"
				su build -c \"./configure $configure_opts\"
				su build -c \"make -j$(nproc)\"
				;;
			esac


			# Publish manuals
			case $repo in
			openbsc)
				for dir in manuals/*/; do
					su build -c \"make -C \$dir publish\"
				done
				;;
			osmo-epdg)
				su build -c \"make -C docs/manuals publish\"
				;;
			*)
				su build -c \"make -C doc/manuals publish\"
				;;
			esac
	"; then
		echo "$LOG_PREFIX Building manuals failed!"
		exit 1
	fi
}

check_ssh_auth_sock

# Get the UserKnownHostsFile for $SSH_COMMAND
clone_repo osmo-gsm-manuals master

get_server_ls "/docs"

for docs_dir in $(cat "$TEMP"/ls_docs); do
	repo="$(get_repo_name_from_docs_dir "$docs_dir")"
	LOG_PREFIX=":: ($repo)"
	get_server_ls "/docs/$docs_dir"
	get_git_tags "$repo"

	echo "$LOG_PREFIX Building missing manuals"
	for tag in $(cat "$TEMP"/git_tags_"$repo"); do
		LOG_PREFIX=":: ($repo, $tag)"
		if manuals_exist "$docs_dir" "$tag"; then
			echo "$LOG_PREFIX: skipping, manuals exist"
			continue
		elif is_tag_ignored "$repo" "$tag"; then
			echo "$LOG_PREFIX: skipping, tag is ignored"
			continue
		fi

		clone_repo "$repo" "$tag"
		build_publish_manuals "$repo" "$tag"
	done
done
