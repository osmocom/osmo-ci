#!/bin/bash

# Executes docker build with the given parameters and retry in case of error.
function build_once() {
	# In case the debian apt archive has become out of sync, try a
	# --no-cache build if it fails.

	# shellcheck disable=SC2068
	docker build $@ -f Dockerfile_osmocom_jenkins.amd64 . \
	|| docker build --no-cache $@ -f Dockerfile_osmocom_jenkins.amd64 .
}

# Builds a container with a debian version and tag name as parameter.
function build_container() {
	local tag_name=${1}
	local debian_version=${2}

	echo "Building for ${debian_version} and setting tag ${tag_name}"
	build_once "-t" "${tag_name}" "--build-arg" DEBIAN_VERSION="${debian_version}"
}

# Create containers using jessie (Debian 8.0) and stretch (Debian 9.0) as base.
build_container osmocom:amd64 jessie
build_container osmocom:deb9_amd64 stretch
