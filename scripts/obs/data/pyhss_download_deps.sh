#!/bin/sh -e
# Copyright 2025 sysmocom - s.f.m.c. GmbH
# SPDX-License-Identifier: GPL-3.0-or-later
# This script downloads all dependencies of PyHSS from the python package
# index, either as binary package for all python versions and CPU architectures
# we care about, or as source package depending on what is available.

check_cwd() {
	if ! [ -e services/hssService.py ]; then
		echo "ERROR: run this script from the PyHSS directory"
		exit 1
	fi
	if [ -d debian/deps ]; then
		echo "ERROR: debian/deps exists already!"
		exit 1
	fi
}

download_deps() {
	local srcpkgs=_temp/requirements-source.txt
	local binpkgs=_temp/requirements-binary.txt
	local py_ver
	local python_versions="
		3.11
		3.12
		3.13
	"
	# See e.g. https://pypi.org/project/SQLAlchemy/#files
	local platform
	local platforms="
		manylinux_2_17_aarch64
		manylinux_2_17_x86_64
	"

	rm -rf _temp
	mkdir _temp

	while IFS= read -r line; do
	        case "$line" in
			# These packages are only available as sources
	                mongo*|pymongo*|mysqlclient*|pysctp*|pycryptodome=*)
				echo "$line" >>"$srcpkgs"
				;;
			# The rest is available as binary packages. This is
			# preferred as dependencies for building some of these
			# are not always available in the target distributions
			# (e.g. pydantic-core is written in rust and tooling
			# for building python + rust is not in debian 12).
			*)
				echo "$line" >>"$binpkgs"
				;;
		esac
	done < "requirements.txt"

	# Build system dependencies must also be installed as we will build
	# offline with --no-index and pip won't use system libraries:
	# https://github.com/pypa/pip/issues/5696
	echo "setuptools" >>"$binpkgs"
	echo "wheel" >>"$binpkgs"
	echo "hatchling" >>"$binpkgs"

	echo ":: Downloading source packages"
	pip download \
		--dest debian/deps \
		--no-binary=:all: \
		-r "$srcpkgs"

	for py_ver in $python_versions; do
		for platform in $platforms; do
			echo ":: Downloading binary packages (python $py_ver, platform $platform)"
			local binpkgs_extra=""

			# Redis depends on async-timeout, which has been upstreamed
			# into Python 3.11+. This means "pip download" may not download
			# it if it runs with a more recent python version, but older
			# distros (debian 12) will need it.
			if [ "$py_ver" = "3.11" ]; then
				binpkgs_extra="async-timeout"
			fi

			pip download \
				--dest debian/deps \
				--python-version "$py_ver" \
				--platform "$platform" \
				--only-binary=:all: \
				-r "$binpkgs" \
				$binpkgs_extra
		done
	done

	rm -r _temp
}

check_cwd
download_deps

echo ":: Success"
