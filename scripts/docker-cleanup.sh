#!/bin/sh -x
# https://osmocom.org/projects/osmocom-servers/wiki/Docker_cache_clean_up

# simple image cleaning code in case docuum isn't running
# delete all but the latest images
if [ -z "$(docker ps -q -f name=docuum)" ]; then
	IMAGES=`docker image ls | grep \^osmocom-build | grep -v latest  | awk -F ' ' '{print $1":"$2}'`
	for f in $IMAGES; do
		docker image rm $f
	done
fi

# delete all containers where we forgot to use --rm with docker run
CONTAINERS="$(docker ps -q -a -f status=exited -f status=created)"
if [ -n "$CONTAINERS" ]; then
	docker rm $CONTAINERS
fi

# remove dangling images, containers, volumes, and networks (not tagged or associated with a container)
docker system prune -f
