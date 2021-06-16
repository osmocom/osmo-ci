#!/bin/sh -e
# Script to test if linting is sane by running it on a whole repository
GIT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
OUT=/tmp/lint_all_out
TYPES="$1"

echo "Running find in $GIT_DIR"
files=$(find \
	"$GIT_DIR" \
	-name '*.c' \
	-o -name '*.h' \
	-o -name '*.cpp' \
	-o -name '*.hpp')

if [ -n "$TYPES" ]; then
	echo "Running checkpath with --types="$TYPES" in $GIT_DIR"

	"$SCRIPT_DIR"/checkpatch/checkpatch.pl \
		-f \
		--color=always \
		--no-summary \
		--no-tree \
		--show-types \
		--terse \
		--types="$TYPES" \
		$files \
		| tee "$OUT"

else
	echo "Running checkpath in $GIT_DIR"

	"$SCRIPT_DIR"/checkpatch/checkpatch_osmo.sh \
		-f \
		--color=always \
		--no-summary \
		--show-types \
		--terse \
		$files \
		| tee "$OUT"
fi

wc -l "$OUT"
