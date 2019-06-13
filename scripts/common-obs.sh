#!/bin/sh
# Various common code used in the OBS (opensuse build service) related osmo-ci shell scripts

# Create the source for a dummy package, that conflicts with another dummy package in the current directory. Example
# of the structure that will be generated:
# osmocom-nightly
# └── debian
#     ├── changelog
#     ├── compat
#     ├── control
#     ├── copyright
#     ├── rules
#     └── source
#         └── format
# $1: name of dummy package (e.g. "osmocom-nightly")
# $2: name of conflicting package (e.g. "osmocom-latest")
osmo_obs_prepare_conflict() {
	local pkgname="$1"
	local pkgname_conflict="$2"
	local pkgver="0.0.0"
	local oldpwd="$PWD"

	mkdir -p "$pkgname/debian/source"
	cd "$pkgname/debian"

	# Fill control, changelog, rules
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
Conflicts: ${pkgname_conflict}
Description: Dummy package, which conflicts with ${pkgname_conflict}
EOF
	cat << EOF > changelog
${pkgname} (${pkgver}) unstable; urgency=medium

  * Dummy package, which conflicts with ${pkgname_conflict}.

 -- Oliver Smith <osmith@sysmocom.de>  Thu, 13 Jun 2019 12:50:19 +0200
EOF
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

	# Put in git repository
	cd ..
	git init .
	git add -A
	git commit -m "auto-commit: $pkgname dummy package" || true
	git tag -f "$pkgver"

	cd "$oldpwd"
}

# Add dependency to all (sub)packages in debian/control and commit the change.
# $1: path to debian/control file
# $2: name of the package to depend on
osmo_obs_add_debian_dependency() {
	# Note: adding the comma at the end should be fine. If there is a Depends: line, it is most likely not empty. It
	# should at least have ${misc:Depends} according to lintian.
	sed "s/^Depends: /Depends: $2, /g" -i "$1"

	git -C "$(dirname "$1")" commit -m "auto-commit: debian: depend on $2" .
}
