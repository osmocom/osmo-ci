#!/bin/sh -ex
# Decide whether to build a tarball from autotools logic (exit 0) or by
# creating a simple git archive (exit 1)

PROJECT="$1"
TAG="$2"

if ! [ -e configure.ac ]; then
	exit 1
fi

case "$PROJECT" in
gapk)
	case "$TAG" in
	v0.*|v1.0)
		# Running gapk's configure involves running libgsmhr/fetch_sources.py,
		# which according to git log doesn't really work unless using the
		# version from master and it looks like we don't want to distribute
		# these sources directly... or else we should just add them to the git
		# repository and not rely on downloading a remote archive that may just
		# change at any time. So create a simple git archive instead.
		exit 1
		;;
	*)
		# Fixed above v1.0
		# https://gerrit.osmocom.org/c/gapk/+/34892/1
		exit 0
		;;
	esac
	;;
strongswan-epdg)
	# Use a simple git archive instead of running configure and "make dist-bzip2"
	# The configure script requires tags to be in a specific format and clashs
	# with our custom tags.
	exit 1
	;;
*)
	exit 0
	;;
esac
