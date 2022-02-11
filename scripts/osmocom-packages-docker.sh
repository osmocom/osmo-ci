#!/bin/sh -ex
# Run osmocom-*-packages.sh in a docker container, so dependencies don't need
# to be installed on the host machine. See osmocom-nightly-packages.sh and
# osmocom-latest-packages.sh for supported environment variables.
SCRIPTS="$(realpath "$(dirname "$0")")"
IMAGE="debian10-obs-submit"
OSCRC="${OSCRC:-.oscrc}"

if ! [ -f "$OSCRC" ]; then
	echo "ERROR: missing OSCRC (should point to OSC credentials file)"
	exit 1
fi

. "$SCRIPTS/common.sh"
docker_images_require "$IMAGE"

case "$FEED" in
nightly|next|latest)
	SCRIPT="osmocom-$FEED-packages.sh"
	;;
*)
	# "2021q1" etc, osmocom-nightly-packages.sh verifies and uses $FEED
	SCRIPT="osmocom-nightly-packages.sh"
	;;
esac

docker run \
	--rm \
	-e "FEED=$FEED" \
	-e "OSMO_OBS_CONFLICT_PKGVER=$OSMO_OBS_CONFLICT_PKGVER" \
	-e "PACKAGES=$PACKAGES" \
	-e "PROJ=$PROJ" \
	-v "$SCRIPTS:/scripts" \
	-v "$(realpath "$OSCRC"):/home/user/.oscrc" \
	"$USER/$IMAGE" \
	sh -c "cd ~ && /scripts/$SCRIPT"
