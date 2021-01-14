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
#   osmocom-nightly
#   └── debian
#       ├── changelog
#       ├── compat
#       ├── control
#       ├── copyright
#       ├── rules
#       └── source
#           └── format
osmo_obs_prepare_conflict_deb() {
	local pkgname="$1"
	shift
	local oldpwd="$PWD"

	mkdir -p "$pkgname/debian/source"
	cd "$pkgname/debian"

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

	# Put in git repository
	cd ..
	git init .
	git add -A
	git commit -m "auto-commit: $pkgname dummy package" || true
	git tag -f "$OSMO_OBS_CONFLICT_PKGVER"

	cd "$oldpwd"
}

# Create conflicting packages
# $1: name of dummy package (e.g. "osmocom-nightly")
# $2-*: name of conflicting packages (e.g. "osmocom-latest")
osmo_obs_prepare_conflict() {
	osmo_obs_prepare_conflict_deb "$@"
}
