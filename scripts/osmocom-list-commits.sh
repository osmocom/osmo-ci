#!/bin/sh -e
# Environment variables:
# * NO_HEADER: do not output the header line when set

FORMAT_STR="%-22s %-42s %9s %-40s %s\n"
URL="https://git.osmocom.org"
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

# Print commit of HEAD for an Osmocom git repository, e.g.:
# "f90496f577e78944ce8db1aa5b900477c1e479b0"
# $1: repository
get_head_commit() {
	# git output:
	# f90496f577e78944ce8db1aa5b900477c1e479b0        HEAD
	ret="$(git ls-remote "$URL/$1" HEAD)"
	ret="$(echo "$ret" | awk '{print $1}')"
	echo "$ret"
}

# Print last tag and related commit for an Osmocom git repository, e.g.:
# "ec798b89700dcca5c5b28edf1a1cd16ea311f30a        refs/tags/1.0.1"
# Print "-" when no tags were found.
# $1: repository
get_last() {
	# git output:
	# ec798b89700dcca5c5b28edf1a1cd16ea311f30a        refs/tags/1.0.1
	# eab5f594b0a7cf50ad97b039f73beff42cc8312a        refs/tags/1.0.1^{}
	# ...
	# 41e7cf115d4148a9f34fcb863b68b2d5370e335d        refs/tags/1.3.1^{}
	# 8a9f12dc2f69bf3a4e861cc9a81b71bdc5f13180        refs/tags/3G_2016_09
	# ee618ecbedec82dfd240334bc87d0d1c806477b0        refs/tags/debian/0.9.13-0_jrsantos.1
	# a3fdd24af099b449c9856422eb099fb45a5595df        refs/tags/debian/0.9.13-0_jrsantos.1^{}
	# ...
	ret="$(git ls-remote --tags "$URL/$1")"
	ret="$(echo "$ret" | grep 'refs/tags/[0-9.]*$' || true)"
	ret="$(echo "$ret" | sort -n -k2)"
	ret="$(echo "$ret" | tail -n 1)"

	if [ -n "$ret" ]; then
		echo "$ret"
	else
		echo "-"
	fi
}

# Header
if [ -z "$NO_HEADER" ]; then
	printf "$FORMAT_STR" "# repository" "clone URL" "last tag" "last tag commit" "HEAD commit"
fi

# Table
for repo in $REPOS; do
	last="$(get_last "$repo")"
	last_tag="$(echo "$last" | cut -d/ -f 3)"
	last_commit="$(echo "$last" | awk '{print $1}')"
	head_commit="$(get_head_commit "$repo")"

	printf "$FORMAT_STR" \
		"$repo.git" \
		"$URL/$repo" \
		"$last_tag" \
		"$last_commit" \
		"$head_commit"
done
