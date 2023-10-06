#!/bin/sh -ex

apt_get="apt-get"
if [ -n "$INSIDE_DOCKER" ]; then
	export DEBIAN_FRONTEND=noninteractive
	apt_get="apt-get -y"
fi

su "$BUILDUSER" -c "tar -C _temp/binpkgs -xvf _temp/srcpkgs/$PACKAGE/*.tar.*"
cd _temp/binpkgs/*

$apt_get update
$apt_get build-dep .

if [ -n "$INSIDE_DOCKER" ]; then
	ip link set eth0 down
fi

su "$BUILDUSER" -c "dpkg-buildpackage -us -uc -j$JOBS"

# Show contents
cd ..
for i in *.deb; do
	dpkg -c "$i"
done
