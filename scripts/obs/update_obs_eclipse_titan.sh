#!/bin/sh -e
# https://osmocom.org/projects/cellular-infrastructure/wiki/Upgrading_eclipse-titan_in_the_Osmocom_OBS
DIR="$(realpath "$(dirname "$0")")"
PROJ="$1"
GIT_URL="https://gitea.osmocom.org/osmith/titan.core"
CHECKOUT="osmocom/9.0.0"

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
		--version-append "~osmocom" \
		"$PROJ" \
		eclipse-titan
}

set -x
prepare_git_repo

if [ -n "$PROJ" ]; then
	update_obs_project
fi
