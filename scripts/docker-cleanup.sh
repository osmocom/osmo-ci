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

# delete all containers where we forgot to use --rm with docker run,
# older than 24 hours
docker container prune --filter "until=24h" -f

# remove unused networks older than 24 hours
docker network prune --filter "until=24h" -f
