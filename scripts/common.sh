#!/bin/sh
# Various functions and variables used in multiple osmo-ci shell scripts
OSMO_GIT_URL="https://git.osmocom.org"

# Print commit of HEAD for an Osmocom git repository, e.g.:
# "f90496f577e78944ce8db1aa5b900477c1e479b0"
# $1: repository
osmo_git_head_commit() {
	# git output:
	# f90496f577e78944ce8db1aa5b900477c1e479b0        HEAD
	ret="$(git ls-remote "$OSMO_GIT_URL/$1" HEAD)"
	ret="$(echo "$ret" | awk '{print $1}')"
	echo "$ret"
}

# Print last tags and related commits for an Osmocom git repository, e.g.:
# "ec798b89700dcca5c5b28edf1a1cd16ea311f30a        refs/tags/1.0.1"
# $1: Osmocom repository
# $2: amount of commit, tag pairs to print (default: 1)
# $3: string to print when there are no tags (default: empty string)
osmo_git_last_commits_tags() {
	# git output:
	# ec798b89700dcca5c5b28edf1a1cd16ea311f30a        refs/tags/1.0.1
	# eab5f594b0a7cf50ad97b039f73beff42cc8312a        refs/tags/1.0.1^{}
	# ...
	# 41e7cf115d4148a9f34fcb863b68b2d5370e335d        refs/tags/1.3.1^{}
	# 8a9f12dc2f69bf3a4e861cc9a81b71bdc5f13180        refs/tags/3G_2016_09
	# ee618ecbedec82dfd240334bc87d0d1c806477b0        refs/tags/debian/0.9.13-0_jrsantos.1
	# a3fdd24af099b449c9856422eb099fb45a5595df        refs/tags/debian/0.9.13-0_jrsantos.1^{}
	# ...
	ret="$(git ls-remote --tags "$OSMO_GIT_URL/$1")"
	ret="$(echo "$ret" | grep 'refs/tags/[0-9.]*$' || true)"
	ret="$(echo "$ret" | sort -V -t/ -k3)"
	ret="$(echo "$ret" | tail -n "$2")"

	if [ -n "$ret" ]; then
		echo "$ret"
	else
		echo "$3"
	fi
}

# Print last commits for an Osmocom git repository, e.g.:
# "ec798b89700dcca5c5b28edf1a1cd16ea311f30a"
# $1: repository
# $2: amount of commits to print (default: 1)
# $3: string to print when there are no tags (default: empty string)
osmo_git_last_commits() {
	ret="$(osmo_git_last_commits_tags "$1" "$2" "$3")"
	echo "$ret" | awk '{print $1}'
}

# Print last tags for an Osmocom git repository, e.g.:
# "1.0.1"
# $1: repository
# $2: amount of commits to print (default: 1)
# $3: string to print when there are no tags (default: empty string)
osmo_git_last_tags() {
	ret="$(osmo_git_last_commits_tags "$1" "$2" "$3")"
	echo "$ret" | cut -d/ -f 3
}

# Print the subdirectory of the repository where the source lies (configure.ac etc.).
# Print nothing when the source is in the topdir of the repository.
osmo_source_subdir() {
	case "$1" in
		openbsc)
			echo "openbsc"
			;;
	esac
}
