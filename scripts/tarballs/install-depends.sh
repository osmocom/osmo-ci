#!/bin/sh -ex
# For releases where no debian/control exists, install the dependencies to pass
# the checks in configure.ac so we can run it before building a release
# tarball.

PROJECT="$1"
TAG="$2"
DEPENDS=""

case "$PROJECT" in
osmo-e1-recorder)
	DEPENDS="
		libosmo-abis-dev
		libosmocore-dev
	"
	;;
gapk)
	DEPENDS="
		libasound2-dev
		libosmocore-dev
	"
	;;
*)
	DEPENDS=""
	;;
esac

if [ -n "$DEPENDS" ]; then
	apt-get update
	apt-get install -y --no-install-recommends $DEPENDS
fi
