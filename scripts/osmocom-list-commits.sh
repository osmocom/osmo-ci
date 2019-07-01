#!/bin/sh -e
# Environment variables:
# * NO_HEADER: do not output the header line when set

. "$(dirname "$0")/common.sh"
FORMAT_STR="%-22s %-42s %9s %-40s %s\n"

# Header
if [ -z "$NO_HEADER" ]; then
	printf "$FORMAT_STR" "# repository" "clone URL" "last tag" "last tag commit" "HEAD commit"
fi

# Table
for repo in $OSMO_RELEASE_REPOS; do
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
