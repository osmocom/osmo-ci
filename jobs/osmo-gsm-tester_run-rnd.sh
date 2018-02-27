#!/bin/sh
set -e -x

# On our hardware, we actually use the example configuration as-is.
export OSMO_GSM_TESTER_CONF="$PWD/osmo-gsm-tester/example"

# debug: provoke a failure
#export OSMO_GSM_TESTER_OPTS="-s debug -t fail"

unlink osmo-gsm-tester/example/resources.conf || true
ln -s resources.conf.rnd osmo-gsm-tester/example/resources.conf

PATH="$PWD/osmo-gsm-tester/src:$PATH" \
  ./osmo-gsm-tester/contrib/jenkins-run.sh
