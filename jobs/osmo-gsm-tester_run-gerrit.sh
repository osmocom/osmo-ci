#!/bin/sh
set -e -x

# On our hardware, we actually use the example configuration as-is.
export OSMO_GSM_TESTER_CONF="$PWD/osmo-gsm-tester/example"

# debug: provoke a failure
#export OSMO_GSM_TESTER_OPTS="-s debug -t fail"

unlink osmo-gsm-tester/example/resources.conf || true
ln -s resources.conf.prod osmo-gsm-tester/example/resources.conf

export OSMO_GSM_TESTER_OPTS="-s nitb_sms:sysmo -s sms:sysmo -s gprs:sysmo"
./osmo-gsm-tester/contrib/jenkins-make-check-and-run.sh
