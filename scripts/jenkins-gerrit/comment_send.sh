#!/bin/sh -e

# By default, a mail notification will only be sent if the gerrit verification
# failed. Add yourself here to also receive notifications on successs.
notify_on_success_users="
	pespin
"

arg_notify=""
for i in $notify_on_success_users; do
	if [ "$GERRIT_PATCHSET_UPLOADER_NAME" = "$i" ]; then
		arg_notify="--notify-on-success"
		break
	fi
done

set -x

./comment_generate.py "$PIPELINE_BUILD_URL" \
	-o gerrit_report.json \
	$arg_notify

ssh \
	-p "$GERRIT_PORT" \
	-l jenkins \
	"$GERRIT_HOST" \
		gerrit \
			review \
			--project "$GERRIT_PROJECT" \
			"$GERRIT_CHANGE_NUMBER,$GERRIT_PATCHSET_NUMBER" \
			--json \
			< gerrit_report.json
