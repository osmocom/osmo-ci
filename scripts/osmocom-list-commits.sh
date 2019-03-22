#!/bin/sh -e
# Environment variables:
# * NO_HEADER: do not output the header line when set

. "$(dirname "$0")/common.sh"
FORMAT_STR="%-22s %-42s %9s %-40s %s\n"
REPOS="
	libasn1c
	libosmo-abis
	libosmocore
	libosmo-netif
	libosmo-sccp
	libsmpp34
	libusrp
	osmo-bsc
	osmo-bts
	osmo-ggsn
	osmo-hlr
	osmo-iuh
	osmo-mgw
	osmo-msc
	osmo-pcu
	osmo-sgsn
	osmo-sip-connector
	osmo-sysmon
	osmo-trx
	osmocom-bb
"

# Header
if [ -z "$NO_HEADER" ]; then
	printf "$FORMAT_STR" "# repository" "clone URL" "last tag" "last tag commit" "HEAD commit"
fi

# Table
for repo in $REPOS; do
	last_tag="$(osmo_git_last_tags "$repo" 1 "-")"
	last_commit="$(osmo_git_last_commits "$repo" 1 "-")"
	head_commit="$(osmo_git_head_commit "$repo")"

	printf "$FORMAT_STR" \
		"$repo.git" \
		"$OSMO_GIT_URL/$repo" \
		"$last_tag" \
		"$last_commit" \
		"$head_commit"
done
