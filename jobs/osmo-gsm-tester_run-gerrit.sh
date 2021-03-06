#!/bin/sh
set -e -x

# debug: provoke a failure
#export OSMO_GSM_TESTER_OPTS="-s debug -t fail"

unlink osmo-gsm-tester/sysmocom/resources.conf || true
ln -s resources.conf.prod osmo-gsm-tester/sysmocom/resources.conf

export OSMO_GSM_TESTER_OPTS="-s nitb_sms:sysmo -s sms:sysmo -s gprs:sysmo"
./osmo-gsm-tester/contrib/jenkins-make-check-and-run.sh
