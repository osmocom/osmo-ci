#!/bin/sh -e
# jenkins-job-builder wrapper for deploying to the Osmocom jenkins server

CONFIG="$HOME/.config/jenkins_jobs/jenkins_jobs_osmo-ci.ini"
GLOBAL_CONFIGS="
	$HOME/.config/jenkins_jobs/jenkins_jobs.ini
	/etc/jenkins_jobs/jenkins_jobs.ini
"

if [ "$(basename "$PWD")" != "osmo-ci" ]; then
	echo "ERROR: run this script from the osmo-ci dir"
	exit 1
fi

for i in $GLOBAL_CONFIGS; do
	if [ -e "$i" ]; then
		echo "ERROR: global config found: $i"
		GLOBAL_CONFIG_FOUND=1
	fi
done
if [ "$GLOBAL_CONFIG_FOUND" = 1 ]; then
	echo "Please rename/remove global config files to prevent deploying to the wrong jenkins server by accident."
	exit 1
fi

if ! [ -e "$CONFIG" ]; then
	echo "ERROR: config not found: $CONFIG"
	echo "You need to create it first, see: $PWD/jobs/README.md"
	exit 1
fi

jenkins-jobs --conf "$CONFIG" "$@"
