#!/bin/sh -ex
SSH_CMD="ssh -o UserKnownHostsFile=/build/contrib/known_hosts -p 48"

# Repositories for which doxygen documentation will be generated and
# uploaded, also dependencies which need to be built
repos_api="
	libosmocore
	libosmo-dsp
	libosmo-netif
	libosmo-abis
	libosmo-sigtran
	libusrp
	osmo-e1d
	osmo-gmr
	osmo-trx
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
	# Some repos ship their API docs in a subdirectory, under a different name
	case "$i" in
	osmo-trx)
		doc_dir="$i/libosmo-trx/doc"
		dest="$i/libosmo-trx"
		;;
	*)
		doc_dir="$i/doc"
		dest="$i"
		;;
	esac

	if ! [ -d "$doc_dir" ]; then
		# e.g. libosmo-abis is built as dependency for others but doesn't
		# have its own doxygen documentation as of writing
		continue
	fi

	# Upload only doxygen output (html/ and latex/ trees, possibly nested in
	# a per-library subdirectory, plus tag files and html.tar), but not the
	# other files in doc/ (Makefiles, examples, manuals, ...). Excluded
	# files that were uploaded previously get deleted on the server.
	rsync \
		-avz \
		--delete \
		--delete-excluded \
		--prune-empty-dirs \
		--include='html/***' \
		--include='latex/***' \
		--include='/*.tag' \
		--include='/html.tar' \
		--include='*/' \
		--exclude='*' \
		-e "$SSH_CMD" \
		./"$doc_dir"/ \
		api@ftp.osmocom.org:web-files/latest/"$dest"/
done
