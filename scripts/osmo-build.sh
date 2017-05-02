#!/bin/sh
#
# This script enables artifacts holding dependencies on a jenkins job level to
# speed up builds. Basically, it holds logic to check whether the necessary artifact
# is available. If so it fetches artifact, unpacks it and if cp/tar succeeded
# it triggers the actual build.
#
# Otherwise it simply builds all dependencies from source by using osmo-build-dep.sh
# and archives deps to the ARTIFACT_STORE afterwards. Revisions of locally built
# dependencies are detrmined after dependencies are built to ensure catching new
# changes in dep_n+1 meanwhile building dep_n.
#
# Furthermore, ARTIFACT_STORE environment variable has to be set on all jenkins slaves.
# The JOB_NAME variable will be injected to each jenkins' job by jenkins itself.
# When using script within a docker container one must inject jenkins' JOB_NAME variable
# to the container and ensure that ARTIFACT_STORE is mounted to the container's
# internal ARTIFACT_STORE.
#
# Artifacts will be stored as follows:
#
#	$ARTIFACT_STORE/$JOB_NAME/<dep_1>.<branch_1>.<rev_1>_...
#		..._<dep_n>.<tag_n>.tar.gz
#
# Note: each matrix-build has its own directory inside ARTIFACT_STORE.
#
# In order to make use of osmo-build.sh one needs to source it, e.g. from
# ./contrib/jenkins.sh. Furthermore, jenkins should check out the git tree of
# the project to be built in the workspace root. Following functions needs to be
# declared within a build script that sources osmo-build.sh:
#
# 	- artifact_name()
# 	- build_deps()
# 	- build_project()
#
# This is an example for building "libosmo-netif" which depends on "libosmocore"
# and "libosmo-abis".
#
#	#!/bin/sh
#
#	artifact_deps() {
#		# $1 will be one of folllowing functions:
#		#     - artifact_name_by_local_repo()
#		#     - artifact_name_by_remote_repo()
#		# osmo-build.sh takes care about which function to use
#
#		x="$($1 libosmocore)"
#		x="${x}_$($1 libosmo-abis)"
#
#		echo "${x}.tar.gz"
#	}
#
#	build_deps() {
#		# all commands to build necessary dependencies
#		osmo-build-dep.sh libosmocore master ac_cv_path_DOXYGEN=false
#		"$deps"/libosmocore/contrib/verify_value_string_arrays_are_terminated.py $(find . -name "*.[hc]")
#		osmo-build-dep.sh libosmo-abis
# }
#
#	build_project() {
#		# Necessary commands to build the project, expecting all dependencies have
#		# been built or fetched. Commands within build_project() will be executed
#		# in jenkins' $WORKSPACE.
#
#		autoreconf --install --force
#		./configure --enable-sanitize
#		$MAKE $PARALLEL_MAKE
#		$MAKE distcheck || cat-testlogs.sh
#	}
#
##
#	# source osmo-build.sh to fire the build
#	. osmo-build.sh

log() {
	set +x
	echo
	echo "[INFO] $1"
	echo
	set -x
}

# SOURCING SANITY
log "source sanity check to ensure that sourcing script holds necessary functions"
type artifact_deps
type build_deps
type build_project
log "check whether necessary dependency build scripts are in PATH"
type osmo-build-dep.sh
type osmo-deps.sh

# BUILD FUNCTIONS
init_build() {

	if [ -z "$JOB_NAME" ]; then
		log "[ERROR] JOB_NAME variable is not set, running in Jenkins?"
		exit 1
	fi

	if [ -z "$ARTIFACT_STORE" ]; then
		log "[ERROR] ARTIFACT_STORE variable is not set on this build slave"
		exit 1
	fi

	base="$(pwd)"
	deps="$base/deps"
	inst="$deps/install"
	rm -rf "$deps" || true

	# obtain the project name from the git clone found in the workspace root
	project=$(git config --get --local remote.origin.url \
		| cut -d '/' -f4 | cut -d '.' -f1)

	# replace invalid char for dirs in $JOB_NAME (jenkins variable)
	# ( '/' separates job name and matrix-axis)
	job_name="$( echo "$JOB_NAME" | tr '/' '_')"

	export base deps inst project job_name
	export PKG_CONFIG_PATH="$inst/lib/pkgconfig:$PKG_CONFIG_PATH"
	export LD_LIBRARY_PATH="$inst/lib"

	log "$project build initialized"
}

build() {

	init_build

	artifact_name="$(artifact_name)"

	if [ -f "$ARTIFACT_STORE/$job_name/$artifact_name" ]; then
		fetch_artifact "$ARTIFACT_STORE/$job_name" "$artifact_name"
	else
		log "Compile $project dependencies from source."
		mkdir -p "$deps"
		rm -rf "$inst"

		build_deps
		archive_artifact
	fi

	log "building $project"
	build_project
}

# ARTIFACT FUNCTIONS
artifact_name() {
	# in case deps is empty or does not exist we
	if [ -d "$deps" ]; then
		artifact_deps "branch_and_rev_of_local_repo"
		cd "$base"
	else
		artifact_deps "branch_and_rev_of_remote_repo"
	fi
}

branch_and_rev_of_local_repo() {
	cd "$deps/$1"
	rev="$(git rev-parse --short HEAD)"
	branch="$(git rev-parse --abbrev-ref HEAD)"

	# check whether it is a tag
	if [ "$branch" = "HEAD" ]; then
		tag="$(git describe --tags HEAD)"
		tag="$(echo "$tag" | tr '/' '_')"
		echo "$1.$tag"
	else
		branch="$( echo "$branch" | tr '/' '_')"
		echo "$1.$branch.$rev"
	fi
}

branch_and_rev_of_remote_repo() {
	if [ -z "${2+x}" ]; then branch="master"; else branch="$2"; fi
	branch="$( echo "$branch" | tr '/' '_')"
	rev="$(git ls-remote "https://git.osmocom.org/$1" "refs/heads/$branch")"

	# check whether branch is a tag
	if [ "$rev" = "" ]; then
		echo "$1.$branch"
	else
		rev="$(echo "$rev" | cut -c 1-7)"
		echo "$1.$branch.$rev"
	fi
}

archive_artifact() {
	log "Archiving artifact to artifactStore."

	cd "$base"
	artifact="$(artifact_name)"
	# temp_job_store is necessary to atomically move it to production.
	temp_job_store="$ARTIFACT_STORE/tmp/$job_name/"
	job_store="$ARTIFACT_STORE/$job_name/"

	if [ ! -f "$temp_job_store/$artifact" ]; then
		mkdir -p "$job_store" "$temp_job_store"
		# remove outdated artifact first to avoid temporarily
		# doubling of artifact storage consumption
		rm -f "$job_store/*"
		tar czf "$temp_job_store/$artifact" "deps"
		mv -n "$temp_job_store/$artifact" "$job_store/$artifact"
		rm -rf "$temp_job_store"

		log_artifact_hash "$job_store/$artifact"
	fi
}

fetch_artifact() {
	log "Fetching artifact from artifactStore."

	log_artifact_hash "$1/$2"
	cp "$1/$2" .
	log_artifact_hash "$2"
	tar xzf "$2"

	if [ $? -gt 0 ]; then
		log "Artifact could not be fetched, triggering build_deps()"
		build_deps
	else
        	log "Artifact successfully fetched, triggering $project compilation"
	fi
}

# checksum is not used by script itself,
# but might be handy in logs when debugging.
log_artifact_hash() {
	log "name: $1 \n sha256: $(sha256sum "$1" | cut -d ' ' -f1)"
}

build
