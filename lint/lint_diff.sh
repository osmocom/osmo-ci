#!/bin/sh -e
# Jenkins runs this script on submitted gerrit patches. Can be used as git pre-commit hook.
COMMIT="$1"
GIT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

if [ -z "$GIT_DIR" ]; then
	echo "ERROR: path is not a git repository: $PWD"
	exit 1
fi

if [ -z "$COMMIT" ]; then
	# Clean worktree: diff last commit against the one before
	COMMIT="HEAD~1"

	if [ -n "$(git status --porcelain)" ]; then
		# Dirty worktree: diff uncommitted changes against last commit
		COMMIT="HEAD"
	fi
fi

ERROR=0

echo "Running docker_run_rm.sh on the whole tree..."
echo
if ! "$SCRIPT_DIR"/docker_run_rm.sh; then
	ERROR=1
fi

echo "Running checkpatch on 'git diff $COMMIT'..."
echo
if ! git diff -U0 "$COMMIT" | "$SCRIPT_DIR/checkpatch/checkpatch_osmo.sh" - \
	--color=always \
	--mailback \
	--show-types \
	--showfile \
	--terse
then
	ERROR=1
fi


if [ "$ERROR" = 1 ]; then
	echo
	echo "Please fix the linting errors above. More information:"
	echo "https://osmocom.org/projects/cellular-infrastructure/wiki/Linting"
	echo

	if [ -n "$JENKINS_HOME" ]; then
		echo "Leaving review comments in gerrit..."
		set -x

		# Run again, but in the proper format for checkpatch_json.py
		# and store the output in a file
		git diff -U0 "$COMMIT" | "$SCRIPT_DIR/checkpatch/checkpatch_osmo.sh" \
			> ../checkpatch_output || true
		cd ..
		# Convert to gerrit review format
		"$SCRIPT_DIR/checkpatch/checkpatch_json.py" \
			checkpatch_output \
			gerrit_report.json \
			"$BUILD_TAG" \
			"$BUILD_URL"
		# Apply as review in gerrit
		ssh \
			-o UserKnownHostsFile=$SCRIPT_DIR/../contrib/known_hosts \
			-p "$GERRIT_PORT" \
			-l jenkins \
			"$GERRIT_HOST" \
				gerrit \
					review \
					--project "$GERRIT_PROJECT" \
					"$GERRIT_CHANGE_NUMBER,$GERRIT_PATCHSET_NUMBER" \
					--json \
					< gerrit_report.json
	fi

	exit 1
fi
