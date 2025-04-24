# Osmocom jenkins jobs

These jenkins.osmocom.org job definitions, managed by
[Jenkins Job Builder](https://docs.openstack.org/infra/jenkins-job-builder/index.html)

## Prepare

Install jenkins-job-builder:

```
# apt-get install jenkins-job-builder
```

Create the following file:

```
~/.config/jenkins_jobs/jenkins_jobs_osmo-ci.ini
```

Make sure the file not world readable to minimally safeguard your jenkins password.
Instead of using your jenkins password, use an *API Token*. To retrieve your token go
to Jenkins via a Webbrowser, click on your Username in the right corner, click on configure,
click on *Show API Toke...*.

`jenkins_jobs_osmo-ci.ini`:

```
[jenkins]
user=my_user_name
password=my_api_token
url=https://jenkins.osmocom.org/jenkins
```

and

```
$ chmod go-rwx jenkins_jobs_osmo-ci.ini
```

## Update a single job on jenkins.osmocom.org

```
$ cd ..
$ ./jenkins-jobs-osmo.sh update jobs/gerrit-verifications.yml gerrit-osmo-msc
```

NOTE: when you supply a name not defined in that yml file, you will not get an
error message, just nothing will happen.

## Update all jobs of one file

```
$ cd ..
$ ./jenkins-jobs-osmo.sh update jobs/gerrit-verifications.yml
```

## Update all jobs in all files

```
$ cd ..
$ ./jenkins-jobs-osmo.sh update jobs/
```

## Troubleshooting

### jenkins.JenkinsException: create[gerrit-osmo-msc] failed

jenkins.osmocom.org is not reachable, or URL in the config file is erratic.
Make sure it is exactly

```
url=https://jenkins.osmocom.org/jenkins
```

### Newlines

Use 'key: |' to keep new lines in multiline values, e.g.:

```
- shell: |
    echo hello
    echo world
```

See also:

* https://yaml-multiline.info/
* https://stackoverflow.com/a/21699210

### Jobs named on cmdline are not updated

Make sure the job name is correct, or just issue an entire yml file without
individual job names.

Also be aware that jobs are only actually updated when anything changed.

## Jenkins labels

Most jenkins jobs should run a docker container and install all required
dependencies inside that, so we don't need to install them on the jenkins node.
These jobs don't need to set a label, they can just run on any generic jenkins
node that has docker available. So if you add a new job, you probably don't
need a label at all.

Existing jobs typically have a label set by the topic they belong to, e.g.:

- osmocom-master
- osmocom-gerrit
- ttcn3

Other labels indicate specific software/hardware works here, e.g.:

- coverity
- hdlc
- osmo-gsm-tester
- podman

## ccache

The jobs from master-builds and gerrit-verifications use ccache. View the
statistics with SSH on the build nodes with:

```
$ CCACHE_DIR=~/ccache/gerrit-verifications ccache -s
$ CCACHE_DIR=~/ccache/master-builds ccache -s
```

Note that running multiple jobs in parallel influence the ccache statistics,
and it's impossible to tell which job caused which change in the stats (that's
why they are not printed at the end of each job, it would be confusing).

## Timers

A lot of the jenkins jobs run daily with a timer:

```
triggers:
  - timed: "H 20 * * *"
```

or weekly:

```
triggers:
  - timed: "H 20 * * H"
```

Use H for the minute / day of week, to have it derivated as hash of the job
name. Replace 20 with the hour (UTC) the job should run.

The jobs follow this timetable, to ensure we don't attempt to use binary
packages before they have been built (leading to failing jobs).

```
18:00 - 21:00 OBS related
  18:XX osmocom-obs-sync (sync Debian:12 etc. with openSUSE OBS)
  19:XX osmocom-obs-check-new-distros
  19:XX osmocom-obs-wireshark
  20:XX osmocom-obs (new binary packages start building on OBS!)

22:00 - 01:00 Jobs that don't need binary packages
  22:XX coverity
  22:XX octsim_osmo-ccid-firmware
  22:XX osmo-gsm-tester-runner (virtual)
  23:XX build-kernels-testenv
  23:XX master-builds-dahdi
  00:XX osmocom-api
  00:XX osmocom-build-tags-against-master
  00:XX osmocom-list-commits
  00:XX registry-rebuild-upload-fpga-build (weekly)
  00:XX registry-triggers
  00:XX registry-update-base-images
  00:XX simtester-sanitize

03:00 - 18:00 Jobs that need binary packages
  03:00 - 08:00 ttcn3-testsuites
  08:00 - 18:00 ttcn3-testsuites-testenv
  04:XX osmocom-release-manuals
  05:XX osmocom-release-tarballs
  06:XX repo-install-test
  06:XX coverity-status (runs intentionally much later than the coverity job)
```

`master-builds`: to avoid complexity, these run throughout the day (H H * * *).
