#!/bin/sh -e
. "$(dirname "$0")/../common.sh"
OSMO_CI_DIR="$(realpath $(dirname "$0")/../..)"
TEMP="$OSMO_CI_DIR/_temp_releases"
WEB_PATH="/downloads/home/releases/web-files"
SSH_COMMAND="ssh -o UserKnownHostsFile=$OSMO_CI_DIR/contrib/known_hosts -p 48"
DOCKER_IMAGE="$USER/debian-bookworm-build"
LOG_PREFIX="::"

OSMO_RELEASE_REPOS="
	gapk
	libasn1c
	libgtpnl
	libosmo-abis
	libosmo-netif
	libosmo-pfcp
	libosmo-sccp
	libosmocore
	libsmpp34
	libusrp
	osmo-bsc
	osmo-bts
	osmo-cbc
	osmo-e1-recorder
	osmo-e1d
	osmo-fl2k
	osmo-gbproxy
	osmo-ggsn
	osmo-gsm-manuals
	osmo-hlr
	osmo-hnbgw
	osmo-hnodeb
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
	osmo_dia2gsup
	osmocom-bb
	rtl-sdr
	simtrace2
"

# Old release tags that are duplicates or where generating the tarball fails
TAGS_IGNORE="
	libosmocore:0.5.0,
	libosmocore:0.5.1,

	libsmpp34:1.12,

	osmo-bsc:1.0.1,
	osmo-bsc:1.1.0,
	osmo-bsc:1.1.1,
	osmo-bsc:1.1.2,
	osmo-bsc:1.2.0,
	osmo-bsc:1.2.1,
	osmo-bsc:1.2.2,

	osmo-bts:0.2.0,
	osmo-bts:0.3.0,

	osmo-hlr:0.0.1,

	osmo-mgw:1.0.1,

	osmo-msc:1.0.1,

	osmo-pcap:0.0.3,

	osmo-pcu:0.1,
	osmo-pcu:0.2,

	osmo-sgsn:0.9.0,
	osmo-sgsn:0.9.1,
	osmo-sgsn:0.9.2,
	osmo-sgsn:0.9.3,
	osmo-sgsn:0.9.4,
	osmo-sgsn:0.9.5,
	osmo-sgsn:0.9.6,
	osmo-sgsn:0.9.8,
	osmo-sgsn:0.9.9,
	osmo-sgsn:0.9.10,
	osmo-sgsn:0.9.11,
	osmo-sgsn:0.9.12,
	osmo-sgsn:0.9.13,
	osmo-sgsn:0.9.14,
	osmo-sgsn:0.9.15,
	osmo-sgsn:0.9.16,
	osmo-sgsn:0.10.0,
	osmo-sgsn:0.10.1,
	osmo-sgsn:0.11.0,
	osmo-sgsn:0.12.0,
	osmo-sgsn:0.13.0,
	osmo-sgsn:0.14.0,
	osmo-sgsn:0.15.0,
	osmo-sgsn:1.0.1,

	osmo-sip-connector:0.0.1,

	osmo-trx:0.2.0,
	osmo-trx:0.3.0,
	osmo-trx:1.3.0,
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

# $1: path on server, e.g. "/releases/osmo-bsc"
get_server_ls() {
	local dir="$1"
	local out="$TEMP/ls$(echo "$dir" | tr / _)"

	echo "$LOG_PREFIX Listing files on server: $dir"

	if [ -e "$out" ]; then
		echo "Skipped, file exists: $out"
		return
	fi

	dir="$(echo "$dir" | sed "s.^/releases.$WEB_PATH.")"
	$SSH_COMMAND releases@ftp.osmocom.org "ls -1 $dir" >"$out"
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

# $1: repository
# $2: tag
tarball_exists() {
	local repo="$1"
	local tag="$2"

	grep -q "^$repo-$tag\.tar\." "$TEMP"/ls_releases_"$repo"
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
	if [ -e debian/control ]; then
		sed -i 's/dh-systemd \(.*\),//g' debian/control
		sed -i 's/python-minimal,//g' debian/control
	fi
}

# Get the desired tarball name, replace / with - in $1.
# $1: project path (osmo-bsc, osmo-msc, simtrace/host, etc.)
# $2: tag
get_tarball_name() {
	local project_path="$1"
	local tag="$2"

	echo "$(echo "$project_path" | tr / -)-$tag.tar.bz2"
}

# $1: repository
# $2: project path (osmo-bsc, osmo-msc, simtrace/host, etc.)
# $3: tag
build_tarball() {
	local repo="$1"
	local project_path="$2"
	local tag="$3"
	local tarball_name="$(get_tarball_name "$project_path" "$tag")"
	local prefix="$(echo "$tarball_name" | sed s/\.tar\.bz2//)"
	local uid_user="$(id -u)"
	echo "$LOG_PREFIX Building release tarball: $tarball_name"

	if ! docker run \
		--rm \
		-e "DEBIAN_FRONTEND=noninteractive" \
		-v "$OSMO_CI_DIR/scripts/tarballs:/tarballs" \
		-v "$TEMP/src:/src" \
		"$DOCKER_IMAGE" \
		sh -ex -c "
			cd /src/$repo

			if [ -e debian/control ]; then
				apt-get update
				apt-get -y build-dep .
			else
				/tarballs/install-depends.sh \"$repo\" \"$tag\"
			fi

			cd /src/$project_path

			# Erlang projects: download build depends
			if [ -e contrib/generate_build_dep.sh ]; then
				su build -c \"HOME=/build contrib/generate_build_dep.sh\"
			fi

			if /tarballs/prefer-configure.sh \"$repo\" \"$tag\"; then
				su build -c \"autoreconf -fi\"
				case \"$repo\" in
				osmo-trx)
					su build -c \"autoreconf -fi osmocom-bb/src/host/trxcon\"
					su build -c \"./configure --with-mstrx\"
					;;
				*)
					su build -c \"./configure\"
					;;
				esac
				su build -c \"make dist-bzip2\"
			else
				su build -c \"git archive --prefix=$prefix/ -o $prefix.tar $tag\"

				# Erlang projects: add build depends to release tarball
				if [ -e build_dep.tar.gz ]; then
					su build -c \"mkdir $prefix\"
					su build -c \"mv build_dep.tar.gz $prefix\"
					su build -c \"tar -rf $prefix.tar $prefix/build_dep.tar.gz\"
				fi

				su build -c \"bzip2 -9 $prefix.tar\"
			fi
	"; then
		echo "$LOG_PREFIX Building tarball failed!"
		exit 1
	fi

	cd "$TEMP/src/$project_path"

	# Adjust the tarball name, e.g. for simtrace2-host-*.tar.bz2
	if ! [ -e "$tarball_name" ]; then
		echo
		mv -v *.tar.bz2 "$tarball_name"
		echo
	fi
}

# $1: repository
# $2: tarball path within the repository dir
publish_tarball() {
	local repo="$1"
	local tarball="$2"
	local tarball_path="$TEMP/src/$repo/$tarball"
	local tarball_path_remote="releases@ftp.osmocom.org:$WEB_PATH/$repo/$(basename "$tarball")"

	echo "$LOG_PREFIX Publishing $tarball"

	if [ ! -e "$tarball_path" ]; then
		echo "$LOG_PREFIX ERROR: tarball not found: $tarball_path"
		exit 1
	fi

	if [ "$PUBLISH" != 1 ]; then
		echo "$LOG_PREFIX Skipping, PUBLISH != 1"
		return
	fi

	$SSH_COMMAND releases@ftp.osmocom.org -- mkdir -p "$WEB_PATH/$repo"
	rsync -vz -e "$SSH_COMMAND" "$tarball_path" $tarball_path_remote
}

# $1: repository
# $2: tag
build_publish_tarballs() {
	local repo="$1"
	local tag="$2"
	local tarballs="$repo-$tag.tar.bz2"

	build_tarball "$repo" "$repo" "$tag"

	case "$repo" in
	simtrace2)
		if [ -e "$TEMP"/src/simtrace2/host/configure.ac ]; then
			build_tarball "simtrace2" "simtrace2/host" "$tag"
			tarballs="$tarballs host/simtrace2-host-$tag.tar.bz2"
		fi
		;;
	esac

	for tarball in $tarballs; do
		publish_tarball "$repo" "$tarball"
	done
}

check_ssh_auth_sock
get_server_ls "/releases"

for repo in $OSMO_RELEASE_REPOS; do
	LOG_PREFIX=":: ($repo)"

	if grep -q "^$repo$" "$TEMP/ls_releases"; then
		get_server_ls "/releases/$repo"
	else
		echo "$LOG_PREFIX No release directory on server"
		touch "$TEMP/ls_releases_$repo"
	fi

	get_git_tags "$repo"

	echo "$LOG_PREFIX Building missing tarballs"
	for tag in $(cat "$TEMP"/git_tags_"$repo"); do
		LOG_PREFIX=":: ($repo, $tag)"
		if tarball_exists "$repo" "$tag"; then
			echo "$LOG_PREFIX Skipping, tarball exists"
			continue
		elif is_tag_ignored "$repo" "$tag"; then
			echo "$LOG_PREFIX Skipping, tag is ignored"
			continue
		fi

		clone_repo "$repo" "$tag"
		build_publish_tarballs "$repo" "$tag"
	done
done
