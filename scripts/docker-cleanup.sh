#!/bin/sh -x
# https://osmocom.org/projects/osmocom-servers/wiki/Docker_cache_clean_up

# delete all containers where we forgot to use --rm with docker run,
# older than 24 hours
docker container prune --filter "until=24h" -f

# remove unused networks older than 24 hours
docker network prune --filter "until=24h" -f
