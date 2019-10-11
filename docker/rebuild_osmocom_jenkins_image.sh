#!/bin/bash -e

# Executes docker build with the given parameters and retry in case of error.
function build_once() {
	# shellcheck disable=SC2068
	docker build $@ -f Dockerfile_osmocom_jenkins.amd64 .
}

# Builds a container with a debian version and tag name as parameter.
function build_container() {
	local tag_name=${1}
	local debian_version=${2}

	echo "Pulling ${debian_version} image"
	docker pull "debian:${debian_version}"

	echo "Building for ${debian_version} and setting tag ${tag_name}"
	build_once "-t" "${tag_name}" "--build-arg" DEBIAN_VERSION="${debian_version}"
}

# Create containers using stretch (Debian 9.0) as base.
build_container osmocom:deb9_amd64 stretch
