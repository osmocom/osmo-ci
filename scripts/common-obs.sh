#!/bin/sh
# Various common code used in the OBS (opensuse build service) related osmo-ci shell scripts
. "$(dirname "$0")/common-obs-conflict.sh"

FEEDS_ALL="
	2021q1
	latest
	next
	nightly
"

osmo_cmd_require \
	dch \
	dh \
	dpkg-buildpackage \
	gbp \
	git \
	meson \
	mktemp \
	osc \
	patch \
	sed

if [ -z "$PROJ" ]; then
	echo "PROJ environment variable is not set"
	exit 1
fi

# Add dependency to all (sub)packages in debian/control and commit the change.
# $1: path to debian/control file
# $2: package name (e.g. "libosmocore")
# $3: dependency package name (e.g. "osmocom-nightly")
# $4: dependency package version (optional, e.g. "1.0.0.202101151122")
osmo_obs_add_depend_deb() {
	local d_control="$1"
	local pkgname="$2"
	local depend="$3"
	local dependver="$4"

	if [ "$pkgname" = "$depend" ]; then
		echo "NOTE: skipping dependency on itself: $depend"
		return
	fi

	if [ -n "$dependver" ]; then
		depend="$depend (= $dependver)"
	fi

	# Note: adding the comma at the end should be fine. If there is a Depends: line, it is most likely not empty. It
	# should at least have ${misc:Depends} according to lintian.
	sed "s/^Depends: /Depends: $depend, /g" -i "$d_control"

	git -C "$(dirname "$d_control")" commit -m "auto-commit: debian: depend on $depend" .
}

# Add dependency to all (sub)packages in rpm spec file
# $1: path to rpm spec file
# $2: package name (e.g. "libosmocore")
# $3: dependency package name (e.g. "osmocom-nightly")
# $4: dependency package version (optional, e.g. "1.0.0.202101151122")
osmo_obs_add_depend_rpm() {
	local spec="$1"
	local pkgname="$2"
	local depend="$3"
	local dependver="$4"

	if [ "$pkgname" = "$depend" ]; then
		echo "NOTE: skipping dependency on itself: $depend"
		return
	fi

	if [ -n "$dependver" ]; then
		depend="$depend = $dependver"
	fi

	( while IFS= read -r line; do
		echo "$line"

		case "$line" in
			# Main package
			"Name:"*)
				echo "Requires: $depend"
				;;
			# Subpackages
			"%package"*)
				echo "Requires: $depend"
				;;
			# Build recipe
			"%build"*)
				if [ -n "$dependver" ]; then
					cat << EOF
# HACK: don't let rpmlint abort the build when it finds that a library depends
# on a package with a specific version. The path used here is listed in:
# https://build.opensuse.org/package/view_file/devel:openSUSE:Factory:rpmlint/rpmlint-mini/rpmlint-mini.config?expand=1
# Instead of writing to the SOURCES dir, we could upload osmocom-rpmlintrc as
# additional source for each package. But that's way more effort, not worth it.
echo "setBadness('shlib-fixed-dependency', 0)" \\
	> "%{_sourcedir}/osmocom-rpmlintrc"

EOF
				fi
				;;
		esac
	  done < "$spec" ) > "$spec.new"

	mv "$spec.new" "$spec"
}

# Copy a project's rpm spec.in file to the osc package dir, set the version/source, depend on the conflicting dummy
# package and 'osc add' it
# $1: oscdir (path to checked out OSC package)
# $2: repodir (path to git repository)
# $3: package name (e.g. "libosmocore")
# $4: dependency package name (e.g. "osmocom-nightly")
# $5: dependency package version (optional, e.g. "1.0.0.202101151122")
osmo_obs_add_rpm_spec() {
	local oscdir="$1"
	local repodir="$2"
	local name="$3"
	local depend="$4"
	local dependver="$5"
	local spec_in="$(find "$repodir" -name "$name.spec.in")"
	local spec="$oscdir/$name.spec"
	local tarball
	local version
	local epoch

	if [ -z "$spec_in" ]; then
		echo "WARNING: RPM spec missing: $name.spec.in"
		return
	fi

	cp "$spec_in" "$spec"

	osmo_obs_add_depend_rpm "$spec" "$name" "$depend" "$dependver"

	# Set version and epoch from "Version: [EPOCH:]VERSION" in .dsc
	version="$(grep "^Version: " "$oscdir"/*.dsc | cut -d: -f2- | xargs)"
	case $version in
	*:*)
		epoch=$(echo "$version" | cut -d : -f 1)
		version=$(echo "$version" | cut -d : -f 2)
		;;
	esac
	if [ -n "$epoch" ]; then
		sed -i "s/^Version:.*/Version:  $version\nEpoch:    $epoch/g" "$spec"
	else
		sed -i "s/^Version:.*/Version:  $version/g" "$spec"
	fi

	# Set source file
	tarball="$(cd "$oscdir" && ls -1 "${name}_"*".tar."*)"
	sed -i "s/^Source:.*/Source:  $tarball/g" "$spec"

	osc add "$spec"
}

# Get the path to a distribution specific patch, either from osmo-ci.git or from the project repository.
# $PWD must be the project repository dir.
# $1: distribution name (e.g. "debian8")
# $2: project repository (e.g. "osmo-trx", "limesuite")
osmo_obs_distro_specific_patch() {
	local distro="$1"
	local repo="$2"
	local ret

	ret="$OSMO_CI_DIR/obs-patches/$repo/build-for-$distro.patch"
	if [ -f "$ret" ]; then
		echo "$ret"
		return
	fi

	ret="debian/patches/build-for-$distro.patch"
	if [ -f "$ret" ]; then
		echo "$ret"
		return
	fi
}

# Check if checkout or build of a given package should be skipped, based on the
# PACKAGES environment variable.
# $1: package name (e.g. "libosmocore")
osmo_obs_skip_pkg() {
	local pkgname="$1"

	if [ -z "$PACKAGES" ]; then
		# Don't skip
		return 1
	fi

	for i in "osmocom-$FEED" $PACKAGES; do
		if [ "$i" = "$pkgname" ]; then
			return 1
		fi
	done

	# Skip
	return 0
}

# Copy an already checked out repository dir and apply a distribution specific patch.
# $PWD must be where all repositories are checked out in subdirs.
# $1: distribution name (e.g. "debian8")
# $2: project repository (e.g. "osmo-trx", "limesuite")
osmo_obs_checkout_copy() {
	local distro="$1"
	local repo="$2"
	local patch

	if osmo_obs_skip_pkg "$repo"; then
		return
	fi

	echo
	echo "====> Checking out $repo-$distro"

	# Verify distro name for consistency
	local distros="
		debian8
		debian10
	"
	local found=0
	local distro_i
	for distro_i in $distros; do
		if [ "$distro_i" = "$distro" ]; then
			found=1
			break
		fi
	done
	if [ "$found" -eq 0 ]; then
		echo "ERROR: invalid distro name: $distro, should be one of: $distros"
		exit 1
	fi

	# Copy
	if [ -d "$repo-$distro" ]; then
		rm -rf "$repo-$distro"
	fi
	cp -a "$repo" "$repo-$distro"
	cd "$repo-$distro"

	# Commit patch
	patch="$(osmo_obs_distro_specific_patch "$distro" "$repo")"
	if [ -z "$patch" ]; then
		echo "ERROR: no patch found for distro=$distro, repo=$repo"
		exit 1
	fi
	patch -p1 < "$patch"
	git commit -m "auto-commit: apply $patch" debian/
	cd ..
}

# Run git-version-gen inside Osmocom repositories, so the .tarball-version
# becomes part of the source repository. Usually this would be done with
# "make dist", but we use git-buildpackage instead.
osmo_obs_git_version_gen() {
	if [ -x ./git-version-gen ]; then
		./git-version-gen . > .tarball-version 2>/dev/null
	fi
}

# Return a version based on the latest tag and commit (e.g. "1.5.1.93.47cc")
# or fall back to the last debian version (e.g. "2.2.6"). Run
# osmo_obs_git_version_gen before. $PWD must be inside a git repository.
osmo_obs_get_commit_version() {
	local version=""

	if [ -e ".tarball-version" ]; then
		version=$(cat .tarball-version)
		# debian doesn't allow '-' in version.
		version=$(echo "$version" | sed	's/-/./g' )
	fi

	# deb version
	deb_version=$(head -1 debian/changelog | cut -d ' ' -f 2 | sed 's,(,,'	| sed 's,),,')
	if [ -z "$version" ] || [ "$version" = "UNKNOWN" ]; then
		version="$deb_version"
	else
		# add epoch from debian/changelog
		case $deb_version in
		*:*)
			epoch=$(echo "$deb_version" | cut -d : -f 1)
			version=$epoch:$version
			;;
		esac
	fi

	echo -n "$version"
}

# Verify that $FEED is in $FEEDS and $FEEDS_ALL
osmo_obs_verify_feed() {
	local i
	local j

	for i in $FEEDS; do
		if [ "$i" != "$FEED" ]; then
			continue
		fi

		for j in $FEEDS_ALL; do
			if [ "$j" = "$i" ]; then
				return
			fi
		done

		echo "feed found in FEEDS but not FEEDS_ALL: $FEED"
		exit 1
	done

	echo "unsupported feed: $FEED"
	exit 1
}
