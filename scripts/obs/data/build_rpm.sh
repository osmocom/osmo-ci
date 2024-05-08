#!/bin/sh -ex

if ! [ -d /home/$BUILDUSER/rpmbuild/SOURCES ]; then
	set +x
	echo "ERROR: rpmdev-setuptree did not run"
	echo "If this is an rpm based system and you want to build the package"
	echo "here, run rpmdev-setuptree. Otherwise consider building the"
	echo "package in docker (-d)."
	exit 1
fi

yum_builddep="yum-builddep"
if [ -n "$INSIDE_DOCKER" ]; then
	yum_builddep="yum-builddep -y"
fi

spec="$(basename "$(find _temp/srcpkgs/"$PACKAGE" -name '*.spec')")"

su "$BUILDUSER" -c "cp _temp/srcpkgs/$PACKAGE/$spec ~/rpmbuild/SPECS"
su "$BUILDUSER" -c "cp _temp/srcpkgs/$PACKAGE/*.tar.* ~/rpmbuild/SOURCES"
su "$BUILDUSER" -c "cp _temp/srcpkgs/$PACKAGE/rpmlintrc ~/rpmbuild/SOURCES"
su "$BUILDUSER" -c "cp /obs/data/rpmmacros ~/.rpmmacros"

# Force refresh of package index data (OS#6038)
if command -v dnf; then
	dnf makecache --refresh
else
	yum clean expire-cache
fi

case "$DISTRO" in
	centos:7)
		# HACK: remove pkg-config as centos7 has pkgconfig instead
		# (which will get pulled in automatically). This could be
		# solved more elegantly, but we only build very few centos7
		# packages, so let's not spend too much time on this. In OBS
		# this is handled in the centos7 prjconf:
		# https://build.opensuse.org/projects/CentOS:CentOS-7/prjconf
		sed -i '/^BuildRequires:.*pkg-config/d' "/home/$BUILDUSER/rpmbuild/SPECS/$spec"
		;;
esac

$yum_builddep "/home/$BUILDUSER/rpmbuild/SPECS/$spec"

if [ -n "$INSIDE_DOCKER" ]; then
	ip link set eth0 down
fi

su "$BUILDUSER" -c "rpmbuild -bb ~/rpmbuild/SPECS/$spec"

# Make built rpms available outside of docker
if [ -n "$INSIDE_DOCKER" ]; then
	su "$BUILDUSER" -c "mv ~/rpmbuild/RPMS/*/*.rpm _temp/binpkgs/"
fi

# Show contents
cd _temp/binpkgs
for i in *.rpm; do
	rpm -qlp "$i"
done
