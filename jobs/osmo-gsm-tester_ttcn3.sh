#!/bin/sh
set -e -x

# On our hardware, we actually use the ttcn3 configuration as-is.
export OSMO_GSM_TESTER_CONF="$PWD/osmo-gsm-tester/sysmocom/ttcn3/main.conf"

# debug: provoke a failure
#export OSMO_GSM_TESTER_OPTS="-s debug -t fail"

unlink osmo-gsm-tester/sysmocom/ttcn3/resources.conf || true
ln -s resources.conf.prod osmo-gsm-tester/sysmocom/ttcn3/resources.conf

PATH="$PWD/osmo-gsm-tester/src:$PATH" \
  ./osmo-gsm-tester/sysmocom/ttcn3/jenkins-run.sh
