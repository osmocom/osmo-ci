#!/bin/sh -e
# Jenkins runs this script on submitted gerrit patches. Can be used as git pre-commit hook.
COMMIT="$1"
GIT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ERROR=0
PROJECT="${GERRIT_PROJECT}"

if [ "$OSMO_LINT" = 0 ]; then
	echo "Skipping lint_diff.sh (OSMO_LINT=0)"
	exit 0
fi

get_project() {
	if [ -n "$PROJECT" ] || ! [ -e .gitreview ]; then
		return
	fi

	PROJECT="$(grep project= .gitreview | cut -d = -f2)"
}

check_git_dir() {
	if [ -z "$GIT_DIR" ]; then
		echo "ERROR: path is not a git repository: $PWD"
		exit 1
	fi
}

set_commit() {
	if [ -z "$COMMIT" ]; then
		# Clean worktree: diff last commit against the one before
		COMMIT="HEAD~1"

		if [ -n "$(git status --porcelain)" ]; then
			# Dirty worktree: diff uncommitted changes against last commit
			COMMIT="HEAD"
		fi
	fi
}

test_docker_run_rm() {
	echo "Running docker_run_rm.sh on the whole tree..."
	echo
	if ! "$SCRIPT_DIR"/docker_run_rm.sh; then
		ERROR=1
	fi
}

test_checkpatch() {
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
}

test_clang_format() {
	local check_projects="
		osmo-asf4-dfu
		osmo-ccid-firmware
	"
	local skip=true
	local i

	if ! [ -e ".clang-format" ] || ! command -v clang-format >/dev/null; then
		return
	fi

	for i in $check_projects; do
		if [ "$i" = "$PROJECT" ]; then
			skip=false
			break
		fi
	done

	if $skip; then
		return
	fi

	echo "Running clang-format on 'git diff $COMMIT'..."
	echo

	# Run clang-format-diff and colorize its output
	local diff="$(git diff -U0 --relative "$COMMIT" \
		| clang-format-diff -p1 \
		| sed 's/^-/\x1b[41m-/;s/^+/\x1b[42m+/;s/^@/\x1b[34m@/;s/$/\x1b[0m/')"

	if ! [ -z "$diff" ]; then
		ERROR=1
		echo "$diff"
	fi
}

test_ruff() {
	local i
	local check_projects="
		osmo-ci
		osmo-dev
		osmo-ttcn3-hacks
	"
	local format_projects="
		osmo-ttcn3-hacks
		osmo-dev
		osmo-ci
	"

	if ! command -v ruff >/dev/null; then
		return
	fi

	for i in $check_projects; do
		if [ "$i" = "$PROJECT" ]; then
			echo "Running 'ruff check'..."
			echo
			ruff check
			break
		fi
	done

	for i in $format_projects; do
		if [ "$i" = "$PROJECT" ]; then
			echo "Running 'ruff format --diff'..."
			echo
			ruff format --diff
			break
		fi
	done
}

show_error() {
	echo
	echo "Please fix the linting errors above. More information:"
	echo "https://osmocom.org/projects/cellular-infrastructure/wiki/Linting"
	echo
}

send_review_comments() {
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
}

get_project
check_git_dir
set_commit
test_ruff
test_docker_run_rm
test_checkpatch
test_clang_format

if [ "$ERROR" = 1 ]; then
	show_error
	if [ -n "$JENKINS_HOME" ]; then
		send_review_comments
	fi
	exit 1
fi
