#!/bin/sh -ex

# Maximum amount of storage that docker images may consume
THRESHOLD="$(cat /opt/docuum/docker_max_image_space)"

DIR="$(dirname "$(realpath "$0")")"
IMG="osmo-ci-docuum"
DOCUUM_UID="1000"
DOCKER_GID="$(getent group docker | cut -d : -f 3)"
PULL_ARG=""

if [ -z "$THRESHOLD" ]; then
	set +x
	echo "ERROR: failed to read threshold from /opt/docuum/docker_max_image_space"
	exit 1
fi

if [ "$INITIAL_BUILD" = 1 ]; then
	PULL_ARG="--pull"
fi

mkdir -p /var/cache/docuum
chown "$DOCUUM_UID" /var/cache/docuum

cd "$DIR"
docker build \
	--build-arg DOCKER_GID="$DOCKER_GID" \
	$PULL_ARG \
	-t "$IMG" \
	.

if [ "$INITIAL_BUILD" = 1 ]; then
	exit 0
fi

docker run \
	--rm \
	--init \
	--name docuum \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v /var/cache/docuum:/home/user \
	"$IMG" \
	sh -c "exec /opt/docuum/docuum --threshold '$THRESHOLD'"
