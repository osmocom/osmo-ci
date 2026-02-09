#!/bin/sh -ex
# Create a bare git repository and add/update shallow clones of linux.git
# branches that are relevant for our CI jobs. Jobs can then quickly clone a
# branch from this git repository and discard it afterwards. This saves disk
# space on our jenkins nodes, and keeps the traffic to git.kernel.org minimal.

set_dest() {
	if [ -n "$1" ]; then
		DEST="$1"
	else
		DEST=/tmp/linux-shallow
	fi

	# Check if an existing repository is from last month, and if that is
	# the case then start with a new repository. This is done because the
	# repository size increases with each fetch: we start with a shallow
	# clone but can't truncate the history after follow-up fetches.
	if [ -e "$DEST/.month" ] && [ "$(cat "$DEST/.month")" != "$(date +%m)" ]; then
		DEST_OLD="$DEST"
		DEST="$DEST-new"
	fi
}

init() {
	if [ -d "$DEST" ]; then
		return
	fi

	mkdir -p "$DEST"
	cd "$DEST"
	git init . --bare

	# Garbage collect in foreground
	git config gc.autoDetach false

	git remote add torvalds "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
	git remote add stable "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
	git remote add net-next "https://git.kernel.org/pub/scm/linux/kernel/git/netdev/net-next.git"

	echo "$(date +%m)" > "$DEST/.month"
}

fetch_branch() {
	local remote="$1"
	local branch="$2"
	local head

	git fetch --no-tags --depth=1 "$remote" "$branch"
	head="$(git log -n1 --pretty=format:"%H" "$remote"/"$branch")"
	git branch --force "$remote-$branch" "$head"

	# Pretty print the current commit for the log
	git -c color.ui=always log -1 --oneline "$remote-$branch"
}

fetch_branches() {
	fetch_branch torvalds "master"

	fetch_branch stable "linux-rolling-stable"
	fetch_branch stable "linux-4.19.y"
	fetch_branch stable "linux-5.10.y"
	fetch_branch stable "linux-6.1.y"
	fetch_branch stable "linux-6.12.y"

	fetch_branch net-next "main"
}

collect_garbage() {
	git gc --no-cruft --prune=now
}

# Replace last month's repository if needed, see the comment in set_dest
replace_old() {
	if [ -z "$DEST_OLD" ]; then
		return
	fi

	mv "$DEST_OLD" "$DEST"-old
	mv "$DEST" "$DEST_OLD"
	rm -rf "$DEST"-old

	DEST="$DEST_OLD"
	DEST_OLD=""
	cd "$DEST"
}

show_size() {
	du -h -s "$DEST"
}

set_dest "$@"
init
cd "$DEST"
fetch_branches
collect_garbage
replace_old
show_size
