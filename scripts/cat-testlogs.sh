#!/bin/sh
#
# Intended for use in jenkins build jobs, like this:
#    export PATH="$PATH:/usr/local/src/buildserver-commons"
#    $MAKE check || cat-testlogs.sh
#
# In the jenkins console output, show the actual failures by printing the test
# logs to the console output. This way we can see how exactly the test failed
# even if a job is older and no workspace is available.

set +x
find . -path "*/testsuite.dir/*/testsuite.log" | while read testlog; do
  echo
  echo
  echo
  echo ======================== "$testlog"
  echo
  cat $testlog
done

# this will be called after a test failure, so make sure to return an error
exit 1
