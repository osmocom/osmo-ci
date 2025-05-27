#!/bin/sh -e
# https://osmocom.org/projects/cellular-infrastructure/wiki/Upgrading_eclipse-titan_in_the_Osmocom_OBS
DIR="$(realpath "$(dirname "$0")")"
PROJ="$1"
GIT_URL="https://gitea.osmocom.org/osmith/titan.core"
CHECKOUT="$2"

if [ $# != 2 ]; then
	echo "usage:"
	echo "  update_obs_eclipse_titan.sh PROJ CHECKOUT"
	echo "example:"
	echo "  update_obs_eclipse_titan.sh home:osmith:latest osmocom/11.0.0"
	exit 1
fi

prepare_git_repo() {
	cd "$DIR"
	if ! [ -d _cache/eclipse-titan ]; then
		mkdir -p _cache
		git -C _cache clone "$GIT_URL" eclipse-titan
	fi

	cd _cache/eclipse-titan
	git fetch
	git clean -fdx
	git checkout -f -B "$CHECKOUT"
	git reset --hard origin/"$CHECKOUT"
}

update_obs_project() {
	cd "$DIR"
	./update_obs_project.py \
		--apiurl https://obs.osmocom.org \
		--docker \
		--allow-unknown-package \
		--git-skip-checkout \
		--git-skip-fetch \
		"$PROJ" \
		eclipse-titan
}

set -x
prepare_git_repo

if [ -n "$PROJ" ]; then
	update_obs_project
fi
