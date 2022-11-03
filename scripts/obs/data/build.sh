#!/bin/sh -e

if ! data/build_"$PACKAGEFORMAT".sh; then
	echo
	echo "ERROR: build failed!"
	echo
	if [ -n "$RUN_SHELL_ON_ERROR" ]; then
		bash
	fi
	exit 1
fi

echo
echo "Build successful!"
echo
