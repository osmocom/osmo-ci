# This file gets included as parameters element of various jobs in the
# gerrit-verifications pipeline. All of these jobs have the same parameters
# and can be called from one run_job() function, without creating log entries
# about undefined parameters (OS#6261). See gerrit-verifications.yml for more
# information.

- string:
    name: BRANCH_CI
    description: |
          osmo-ci.git branch
    default: 'master'
- string:
    name: COMMENT_TYPE
    description: set by gerrit verification pipeline job
- string:
    name: DISTRO
    description: set by gerrit verification pipeline job
- string:
    name: GERRIT_BRANCH
    description: set by gerrit verification pipeline job
- string:
    name: GERRIT_CHANGE_NUMBER
    description: set by gerrit verification pipeline job
- string:
    name: GERRIT_HOST
    description: set by gerrit verification pipeline job
- string:
    name: GERRIT_PATCHSET_NUMBER
    description: set by gerrit verification pipeline job
- string:
    name: GERRIT_PATCHSET_REVISION
    description: set by gerrit verification pipeline job
- string:
    name: GERRIT_PATCHSET_UPLOADER_NAME
    description: set by gerrit verification pipeline job
- string:
    name: GERRIT_PORT
    description: set by gerrit verification pipeline job
- string:
    name: GERRIT_PROJECT
    description: set by gerrit verification pipeline job
- string:
    name: GERRIT_REFSPEC
    description: set by gerrit verification pipeline job
- string:
    name: GERRIT_REPO_URL
    description: set by gerrit verification pipeline job
- string:
    name: PIPELINE_BUILD_URL
    description: set by gerrit verification pipeline job
- string:
    name: PROJECT_NAME
    description: set by gerrit verification pipeline job
