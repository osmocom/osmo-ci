#!/bin/sh
set -e -x

# debug: provoke a failure
#export OSMO_GSM_TESTER_OPTS="-s debug -t fail"

unlink osmo-gsm-tester/sysmocom/resources.conf || true
ln -s resources.conf.prod osmo-gsm-tester/sysmocom/resources.conf

PATH="$PWD/osmo-gsm-tester/src:$PATH" \
  ./osmo-gsm-tester/contrib/jenkins-run.sh
