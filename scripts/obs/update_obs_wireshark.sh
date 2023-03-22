#!/bin/sh -e
DIR="$(realpath "$(dirname "$0")")"
PROJ="$1"

BRANCHES="
	osmith/deb-packaging
	laforge/doc-fixes
	osmocom/qcdiag
	laforge/rspro
"

prepare_git_repo() {
	cd "$DIR"
	if ! [ -d _cache/wireshark ]; then
		mkdir -p _cache
		git -C _cache clone https://gitlab.com/wireshark/wireshark.git
		git -C _cache/wireshark remote add osmocom https://gitea.osmocom.org/osmocom/wireshark
	fi

	cd _cache/wireshark
	git fetch --all
	git clean -fdx
	git checkout -f -B osmocom/all-in-one origin/master

	for b in $BRANCHES; do
		git merge --no-edit "osmocom/$b"
	done
}

update_obs_project() {
	cd "$DIR"
	./update_obs_project.py \
		--apiurl obs.osmocom.org \
		--docker \
		--allow-unknown-package \
		--git-skip-checkout \
		--git-skip-fetch \
		--version-append "~osmocom" \
		"$PROJ" \
		wireshark
}

set -x
prepare_git_repo

if [ -n "$PROJ" ]; then
	update_obs_project
fi
