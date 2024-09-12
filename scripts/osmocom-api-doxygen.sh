#!/bin/sh -ex
SSH_CMD="ssh -o UserKnownHostsFile=/build/contrib/known_hosts -p 48"

# Repositories for which doxygen documentation will be generated and
# uploaded, also dependencies which need to be built
repos_api="
	libosmocore
	libosmo-abis
	libosmo-dsp
	libosmo-netif
	libosmo-sigtran
	osmo-gmr
"

# Source common.sh from osmo-ci.git for osmo_git_clone_url()
. scripts/common.sh

# Check early that SSH works
$SSH_CMD api@ftp.osmocom.org -T -- true

# Put git repos and install data in a subdir, so it isn't in the root
# of the cloned osmo-ci.git repository
mkdir _osmocom_api
cd _osmocom_api

# Prepare pkgconfig path
export PKG_CONFIG_PATH=$PWD/install/lib/pkgconfig
mkdir -p "$PKG_CONFIG_PATH"

# Clone and build the repositories
for i in $repos_api; do
	git clone "$(osmo_git_clone_url "$i")"
	cd "$i"
	autoreconf -fi
	./configure \
		--prefix=$PWD/../install \
		--with-systemdsystemunitdir=no
	make $PARALLEL_MAKE install
	cd ..
done

# Upload all docs
for i in $repos_api; do
	if ! [ -d "$i"/doc ]; then
		# e.g. libosmo-abis is built as dependency for others but doesn't
		# have its own doxygen documentation as of writing
		continue
	fi

	rsync \
		-avz \
		--delete \
		-e "$SSH_CMD" \
		./"$i"/doc/ \
		api@ftp.osmocom.org:web-files/latest/"$i"/
done
