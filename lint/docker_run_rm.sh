#!/bin/sh
# Verify that "docker run" has a "--rm" in the same line or next line, so we
# don't fill up space on jenkins nodes with never deleted containers:
# https://osmocom.org/projects/osmocom-servers/wiki/Docker_cache_clean_up

RET=0

for i in $(git grep -l '^[^#]*docker run'); do
	if [ -z "$(grep -A1 "docker run" "$i" | grep -- "--rm")" ]; then
		echo "ERROR: missing --rm after 'docker run' (same line or next line):"
		grep --color=always -H -n -A1 "docker run" "$i"
		echo
		RET=1
	fi
done

exit $RET
