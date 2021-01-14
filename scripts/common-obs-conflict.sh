#!/bin/sh
# Create conflicting dummy packages in OBS (opensuse build service), so users can't mix packages
# built from different branches by accident

OSMO_OBS_CONFLICT_PKGVER="1.0.0"

# Create the conflicting package for debian
#
# $1: name of dummy package (e.g. "osmocom-nightly")
# $2-*: name of conflicting packages (e.g. "osmocom-latest")
#
# Generates the following directory structure:
#   debian
#   ├── changelog
#   ├── compat
#   ├── control
#   ├── copyright
#   ├── rules
#   └── source
#       └── format
osmo_obs_prepare_conflict_deb() {
	local pkgname="$1"
	shift
	local oldpwd="$PWD"

	mkdir -p "debian/source"
	cd "debian"

	# Fill control
	cat << EOF > control
Source: ${pkgname}
Section: unknown
Priority: optional
Maintainer: Oliver Smith <osmith@sysmocom.de>
Build-Depends: debhelper (>= 9)
Standards-Version: 3.9.8

Package: ${pkgname}
Depends: \${misc:Depends}
Architecture: any
EOF
	printf "Conflicts: " >> control
	first=1
	for i in "$@"; do
		if [ "$first" -eq 1 ]; then
			first=0
		else
			printf ", " >> control
		fi
		printf "%s" "$i" >> control
	done
	printf "\n" >> control
	cat << EOF >> control
Description: Dummy package, which conflicts with: $@
EOF

	# Fill changelog
	cat << EOF > changelog
${pkgname} (${OSMO_OBS_CONFLICT_PKGVER}) unstable; urgency=medium

  * Dummy package, which conflicts with: $@

 -- Oliver Smith <osmith@sysmocom.de>  Thu, 13 Jun 2019 12:50:19 +0200
EOF

	# Fill rules
	cat << EOF > rules
#!/usr/bin/make -f
%:
	dh \$@
EOF

	# Finish up debian dir
	chmod +x rules
	echo "9" > compat
	echo "3.0 (native)" > source/format
	touch copyright

	cd "$oldpwd"
}

# Create the conflicting package for rpm (e.g. contrib/osmocom-nightly.spec.in). The remaining
# placeholders are replaced in osmo_obs_add_rpm_spec().
#
# $1: name of dummy package (e.g. "osmocom-nightly")
# $2-*: name of conflicting packages (e.g. "osmocom-latest")
osmo_obs_prepare_conflict_rpm() {
	local pkgname="$1"
	shift
	local spec_in="contrib/$pkgname.spec.in"

	mkdir -p contrib

	cat << EOF > "$spec_in"
Name:    $pkgname
Version: @VERSION@
Release: 0
Summary: Dummy package, which conflicts with: $@
License: AGPL-3.0-or-later
Group:   Hardware/Mobile
Source:  @SOURCE@
EOF

	for i in "$@"; do
		echo "Conflicts: $i" >> "$spec_in"
	done

	cat << EOF >> "$spec_in"
%description
Dummy package, which conflicts with: $@
%files
EOF

}

# Create conflicting packages
# $1: name of dummy package (e.g. "osmocom-nightly")
# $2-*: name of conflicting packages (e.g. "osmocom-latest")
osmo_obs_prepare_conflict() {
	local pkgname="$1"
	local oldpwd="$PWD"

	mkdir -p "$pkgname"
	cd "$pkgname"

	osmo_obs_prepare_conflict_deb "$@"
	osmo_obs_prepare_conflict_rpm "$@"

	# Put in git repository
	git init .
	git add -A
	git commit -m "auto-commit: $pkgname dummy package" || true
	git tag -f "$OSMO_OBS_CONFLICT_PKGVER"

	cd "$oldpwd"
}
