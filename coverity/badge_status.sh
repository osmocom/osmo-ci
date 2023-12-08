#!/bin/sh -e
# Check if the coverity badge says "failed". This can happen for example if we
# use a coverity version that is no longer supported, and it doesn't fail in
# any other obvious way. (SYS#6685)

# Download the status badge svg image, which contains the word "passed" when
# it was successful, and "failed" when it failed.
# Example: <text x="62" y="14">passed 91 new defects</text>

BADGE="_temp/badge.svg"

mkdir -p _temp
rm -f "$BADGE"

wget --no-verbose -O "$BADGE" "https://scan.coverity.com/projects/7523/badge.svg"

if grep -q passed "$BADGE" && ! grep -q failed "$BADGE"; then
	echo "Success"
	exit 0
fi

echo
echo "ERROR: coverity failed!"
echo
echo "Find the error details here:"
echo "https://scan.coverity.com/projects/osmocom?tab=overview"
echo
exit 1
