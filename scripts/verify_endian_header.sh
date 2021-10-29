#!/bin/sh

# Usage: ./verify_endian_header.sh $(find . -name "*.[hc]")

HEADER="osmocom/core/endian.h"
COUNT=0

for f in $*; do
	# Obviously, ignore the header file defining the macros
	if [ $(basename $f) = $(basename $HEADER) ]; then
		continue
	fi
	# Match files using either of OSMO_IS_{LITTLE,BIG}_ENDIAN
	if grep -q "OSMO_IS_\(LITTLE\|BIG\)_ENDIAN" $f; then
		# The header file must be included
		if ! grep -q "#include <$HEADER>" $f; then
			echo "File '$f' does not #include <$HEADER>"
			COUNT=$((COUNT + 1))
		fi
	fi
done

exit $COUNT
