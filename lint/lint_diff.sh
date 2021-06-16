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

echo "Running checkpatch on 'git diff $COMMIT'..."
echo
if git diff -U0 "$COMMIT" | "$SCRIPT_DIR/checkpatch/checkpatch_osmo.sh" - \
	--color=always \
	--mailback \
	--show-types \
	--showfile \
	--terse
then
	exit 0
fi

echo
echo "Please fix the linting errors above. More information:"
echo "https://osmocom.org/projects/cellular-infrastructure/wiki/Linting"
echo
exit 1
