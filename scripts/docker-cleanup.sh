#!/bin/sh -x
# https://osmocom.org/projects/osmocom-servers/wiki/Docker_cache_clean_up

kill_docker_containers_running_longer_than_24h() {
	docker ps
	set +x

	local date_24h_ago="$(date "+%s" -d"24 hours ago")"
	docker ps --format "{{.ID}}|{{.Names}}|{{.CreatedAt}}" | while read -r line; do
		local id="$(echo "$line" | cut -d '|' -f 1)"
		local name="$(echo "$line" | cut -d '|' -f 2)"
		local created_at="$(echo "$line" | cut -d '|' -f 3 | cut -d ' ' -f 1-3)"
		local date_created_at="$(date "+%s" -d "$created_at")"

		if [ "$date_created_at" -gt "$date_24h_ago" ]; then
			echo "$name: not running for >24h"
			continue
		fi

		case "$name" in
		jenkins-*|*ttcn3*|osmo-gsm-tester*) ;;
		*)
			echo "$name: does not match name pattern"
			continue
			;;
		esac

		echo "$name ($id): has been running for >24h, killing"
		docker kill "$id"
	done

	set -x
	docker ps
}

kill_docker_containers_running_longer_than_24h

# delete all containers where we forgot to use --rm with docker run,
# older than 24 hours
docker container prune --filter "until=24h" -f

# remove unused networks older than 24 hours
docker network prune --filter "until=24h" -f

# remove docker buildkit cache
docker builder prune --all --filter "until=24h" -f
