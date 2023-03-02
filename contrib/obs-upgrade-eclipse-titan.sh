#!/bin/sh -e
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright 2023 sysmocom - s.f.m.c. GmbH
# Author: Oliver Smith
#
# Helper script to upgrade the eclipse-titan package on obs.osmocom.org.
# Usage instructions:
# https://osmocom.org/projects/cellular-infrastructure/wiki/Upgrading_eclipse-titan_in_the_Osmocom_OBS

old_dsc="$(find -maxdepth 1 -name 'eclipse-titan_*.dsc')"
old_ver="$(grep '^Version: ' "$old_dsc" | cut -d ':' -f 2 | xargs | cut -d - -f 1)"
new_ver="$1"

if [ -z "$new_ver" ]; then
	echo "usage: update.sh NEW_VERSION"
	exit 1
fi

echo ":: upgrade from $old_ver to $new_ver"

tarball="titan.core-$new_ver.tar.bz2"
if ! [ -e "$tarball" ]; then
	echo ":: download $tarball"
	wget "https://gitlab.eclipse.org/eclipse/titan/titan.core/-/archive/$new_ver/$tarball"
fi

echo ":: extract $old_dsc"
dpkg-source -x "$old_dsc"

echo ":: update sourcedir with $tarball"
cd "eclipse-titan-$old_ver"
uupdate -v "$new_ver" ../"$tarball"

echo ":: now modify eclipse-titan-$new_ver (e.g. adjust changelog) and press return when done"
read foo

echo ":: build new source package"
cd "../eclipse-titan-$new_ver"
dpkg-buildpackage -S -uc -us -d
cd ".."

echo ":: clean up extracted dirs"
rm -rf "eclipse-titan-$old_ver" \
	"eclipse-titan-$new_ver" \
	"eclipse-titan-$new_ver.orig" \
	*.buildinfo \
	*.changes

echo ":: done!"
