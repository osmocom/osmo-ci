#!/bin/bash
# Generate source packages and upload them to OBS, for the next feed.
. "$(dirname "$0")/common.sh"

export FEED="next"
$OSMO_CI_DIR/scripts/osmocom-nightly-packages.sh
