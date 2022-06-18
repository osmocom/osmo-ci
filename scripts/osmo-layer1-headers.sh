#!/bin/sh

# -e: fail if any of the subsequent commands fail
# -x: trace each executed command via debug log
set -e -x

# Usage:
# ./osmo-layer1-headers.sh sysmo superfemto_v5.1
# where 'sysmo' is BTS type and 'superfemto_v5.1' is version specifier (tag or branch for git reset)
# 2nd parameter is optional and defaults to latest master branch

case "$1" in
    sysmo)
	uri="https://gitea.sysmocom.de/sysmo-bts/layer1-api"
	version_prefix=""
	version="origin/master"
	;;
    oct)
	uri="https://git.osmocom.org/octphy-2g-headers"
	version_prefix=""
	version="origin/master"
	;;
    lc15)
	uri="https://gitlab.com/nrw_litecell15/litecell15-fw"
	version_prefix="origin/nrw/"
	version="origin/nrw/litecell15"
	;;
    oc2g)
	uri="https://gitlab.com/nrw_oc2g/oc2g-fw"
	version_prefix="origin/nrw/"
	version="origin/nrw/oc2g"
	;;
    *)
	echo "Unknown BTS model '$1'"
	exit 1
	;;
esac

# if 2nd parameter was specified and it's not 'master' then use it instead of default
if [ -n "$2" ]
then
    if [ "$2" != "master" ]
    then
	version=$2
    fi
fi

if ! test -d layer1-headers;
then
    git clone "$uri" layer1-headers
fi

cd layer1-headers
git fetch origin
# $version_prefix is an ugly workaround for jenkins not being able to deal with slash ('/')
# in label names that comprise the axis of a matrxi buildjob, while nuran not using tags but
# only branch names in their firmware repositories :(
git checkout -f "$version" || git checkout -f "${version_prefix}${version}"
