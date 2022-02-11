#!/bin/sh -x

# delete all but the latest images
IMAGES=`docker image ls | grep \^osmocom-build | grep -v latest  | awk -F ' ' '{print $1":"$2}'`
for f in $IMAGES; do
	docker image rm $f
done

docker image prune -f
