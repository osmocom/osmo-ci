#!/bin/sh
set -e -x

# On our hardware, we actually use the example configuration as-is.
export OSMO_GSM_TESTER_CONF="$PWD/osmo-gsm-tester/ttcn3"

# debug: provoke a failure
#export OSMO_GSM_TESTER_OPTS="-s debug -t fail"

unlink osmo-gsm-tester/ttcn3/resources.conf || true
ln -s resources.conf.prod osmo-gsm-tester/ttcn3/resources.conf

PATH="$PWD/osmo-gsm-tester/src:$PATH" \
  ./osmo-gsm-tester/ttcn3/jenkins-run.sh
