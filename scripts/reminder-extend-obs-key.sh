#!/bin/sh -ex
mkdir -p _temp
cd _temp

if ! [ -e public_key ]; then
	wget -q https://obs.osmocom.org/projects/osmocom/public_key
fi

gpg --show-keys public_key

EXPIRATION_DATE="$(gpg --show-keys public_key | grep -o 'expires: [0-9-]*' | cut -d ' ' -f2)"
EXPIRATION_DATE_S="$(date -d "$EXPIRATION_DATE" +%s)"
ONE_YEAR_FROM_NOW="$(date -d "+365 days" +%Y-%m-%d)"
ONE_YEAR_FROM_NOW_S="$(date -d "$ONE_YEAR_FROM_NOW" +%s)"

set +x

if [ "$(echo "$EXPIRATION_DATE" | wc -l)" != 1 ] || [ "$EXPIRATION_DATE_S" -lt "$(date -d "2026-01-01" +%s)" ]; then
	echo "Failed to get valid expiration date"
	exit 1
fi

if [ "$ONE_YEAR_FROM_NOW_S" -lt "$(date -d "2026-01-01" +%s)" ]; then
	echo "Failed to get date one year from now"
	exit 1
fi

echo
echo "Checking if expiration date ($EXPIRATION_DATE) is in less than a year from now ($ONE_YEAR_FROM_NOW)..."

if [ "$ONE_YEAR_FROM_NOW_S" -gt "$EXPIRATION_DATE_S" ]; then
	echo
	echo "============================================================="
	echo "The OBS signing key must be extended!"
	echo
	echo "Instructions:"
	echo "https://osmocom.org/projects/osmocom-servers/wiki/OBS_server_setup#Extending-singing-key"
	echo
	echo "The key becomes valid for 2 years, we extend it after 1 year."
	echo "============================================================="
	echo
	exit 1
else
	echo "=> OK"
fi
