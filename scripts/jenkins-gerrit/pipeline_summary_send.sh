#!/bin/sh -ex

./pipeline_summary.py "$PIPELINE_BUILD_URL" -o gerrit_report.json

ssh \
	-p "$GERRIT_PORT" \
	-l jenkins \
	"$GERRIT_HOST" \
		gerrit \
			review \
			"$GERRIT_PATCHSET_REVISION" \
			--json \
			< gerrit_report.json
