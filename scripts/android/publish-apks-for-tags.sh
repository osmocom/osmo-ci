#!/bin/sh -e
# Publish Android apks for tags, signed with a test key (to be re-signed with a
# proper key later on, see SYS#7197).

. "$(dirname "$0")/../common.sh"
OSMO_CI_DIR="$(realpath $(dirname "$0")/../..)"
TEMP="$OSMO_CI_DIR/_temp_apks"
WEB_PATH="/downloads/home/binaries/web-files/android/.apks_testsig"
SSH_COMMAND="ssh -o UserKnownHostsFile=$OSMO_CI_DIR/contrib/known_hosts -p 48"
DOCKER_IMAGE="$USER/debian-bookworm-android"
LOG_PREFIX="::"

OSMO_RELEASE_REPOS="
	android-apdu-proxy
"

if [ "$JENKINS" = 1 ]; then
	DOCKER_IMAGE="registry.osmocom.org/$DOCKER_IMAGE"
fi

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

	$SSH_COMMAND binaries@ftp.osmocom.org "ls -1 "$WEB_PATH$dir"" >"$out"
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
apk_exists() {
	local repo="$1"
	local tag="$2"

	grep -q "^$repo-$tag\.apk" "$TEMP"/ls_"$repo"
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
}

build_apk() {
	local repo="$1"
	local tag="$2"
	local gitdir="$TEMP/src/$repo"

	cd "$gitdir"

	echo "$LOG_PREFIX Building $repo-$tag.apk"

	ANDROID_CACHE="$HOME/android-cache/master-builds/android"
	GRADLE_CACHE="$HOME/android-cache/master-builds/gradle"
	mkdir -p "$ANDROID_CACHE" "$GRADLE_CACHE"

	if [ "$JENKINS" = 1 ]; then
		docker pull "$DOCKER_IMAGE"
	fi

	docker run --rm=true \
		-e HOME=/build \
		-i \
		-u build \
		-v "$ANDROID_CACHE":/build/.android \
		-v "$GRADLE_CACHE":/build/.gradle \
		-v "$PWD:/build" \
		-w /build \
		"$DOCKER_IMAGE" \
		timeout 60m contrib/jenkins.sh
}

publish_apk() {
	local repo="$1"
	local tag="$2"
	local apk_path_local="$TEMP/src/$repo/app/build/outputs/apk/release/app-release.apk"

	echo "$LOG_PREFIX Publishing $repo-$tag.apk"

	$SSH_COMMAND binaries@ftp.osmocom.org -- mkdir -p "$WEB_PATH/$repo"
	rsync \
		-vz \
		-e "$SSH_COMMAND" \
		"$apk_path_local" \
		"binaries@ftp.osmocom.org:$WEB_PATH/$repo/$repo-$tag.apk"
}

check_ssh_auth_sock
get_server_ls "/"

for repo in $OSMO_RELEASE_REPOS; do
	LOG_PREFIX=":: ($repo)"

	if grep -q "^$repo$" "$TEMP/ls_"; then
		get_server_ls "/$repo"
	else
		echo "$LOG_PREFIX No release directory on server"
		touch "$TEMP/ls_$repo"
	fi

	get_git_tags "$repo"

	echo "$LOG_PREFIX Building missing apks"
	for tag in $(cat "$TEMP"/git_tags_"$repo"); do
		LOG_PREFIX=":: ($repo, $tag)"
		if apk_exists "$repo" "$tag"; then
			echo "$LOG_PREFIX Skipping, apk exists"
			continue
		fi

		clone_repo "$repo" "$tag"
		build_apk "$repo" "$tag"
		publish_apk "$repo" "$tag"
	done
done
