#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import argparse
import io
import json
import re
import urllib.request
import sys

jenkins_url = "https://jenkins.osmocom.org"
re_start_build = re.compile("Starting building: gerrit-[a-zA-Z-_0-9]* #[0-9]*")
re_result = re.compile("^pipeline_([a-zA-Z-_0-9:]*): (SUCCESS|FAILED)$")
re_job_type = re.compile("JOB_TYPE=([a-zA-Z-_0-9]*),")
re_distro = re.compile("Building binary packages for distro: '([a-zA-Z0-9:].*)'")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Prepare a comment to be submitted to gerrit. Depending on"
                    " the comment type, (start) either a link to the pipeline,"
                    " or (result) a summary of failed / successful builds from"
                    " the pipeline we run for patches submitted to gerrit.")
    parser.add_argument("build_url",
                        help="$BUILD_URL of the pipeline job, e.g."
                             " https://jenkins.osmocom.org/jenkins/job/gerrit-osmo-bsc-nat/17/")
    parser.add_argument("-o", "--output", help="output json file")
    parser.add_argument("-t", "--type", help="comment type",
                        choices=["start", "result"], required=True)
    parser.add_argument("-n", "--notify-on-success", action="store_true",
                        help="always indicate in json that the owner should be"
                             " notified via mail, not only on failure")
    return parser.parse_args()


def stage_binpkgs_from_url(job_url):
    """ Multiple gerrit-binpkgs jobs may be started to build binary packages
        for multiple distributions. It is not clear from the job name / URL of
        a job for which distro it is building, so read it from the log output.
        :returns: a distro like "debian:12" """
    global re_distro

    url = f"{job_url}/consoleText"
    print(f"Reading {url}")
    with urllib.request.urlopen(url) as response:
        content = response.read().decode("utf-8", errors="ignore")
        match = re_distro.search(content)
        assert match, f"couldn't find distro name in log: {url}"
        return match.group(1)


def stage_from_job_name(job_name, job_url):
    if job_name == "gerrit-verifications-comment":
        # The job that runs this script. Don't include it in the summary.
        return None
    if job_name == "gerrit-lint":
        return "lint"
    if job_name == "gerrit-binpkgs":
        return stage_binpkgs_from_url(job_url)
    if job_name == "gerrit-pipeline-endianness":
        return "endianness"
    if job_name.endswith("-build"):
        return "build"
    assert False, f"couldn't figure out stage from job_name: {job_name}"


def parse_pipeline(build_url):
    """ Parse started jobs and result from the pipeline log.
       :returns: a dict that looks like:
                 {"build": {"name": "gerrit-osmo-bsc-nat-build", id=7,
                            "passed": True, "url": "https://..."},
                  "lint": {...},
                  "deb": {...},
                  "rpm: {...}} """
    global re_start_build
    global re_result
    global jenkins_url
    ret = {}

    url = f"{build_url}/consoleText"
    print(f"Reading {url}")
    with urllib.request.urlopen(url) as response:
        for line in io.TextIOWrapper(response, encoding='utf-8'):
            # Parse start build lines
            for match in re_start_build.findall(line):
                job_name = match.split(" ")[2]
                job_id = int(match.split(" ")[3].replace("#", ""))
                job_url = f"{jenkins_url}/jenkins/job/{job_name}/{job_id}"
                stage = stage_from_job_name(job_name, job_url)
                if stage:
                    ret[stage] = {"url": job_url, "name": job_name, "id": job_id}

            # Parse result lines
            match = re_result.match(line)
            if match:
                stage = match.group(1)
                if stage.startswith("comment_"):
                    # Jobs that run this script, not relevant for summary
                    continue
                if stage not in ret:
                    print(f"URL: {url}")
                    print()
                    print(f"ERROR: found result for stage {stage}, but didn't"
                          " find where it was started. Possible reasons:")
                    print("* The re_stat_build regex needs to be adjusted"
                          " to match the related gerrit-*-build job")
                    print("* The gerrit-*-build job has not been deployed,"
                          " and therefore could not be started by the"
                          " gerrit-* job.")
                    sys.exit(1)
                ret[stage]["passed"] = (match.group(2) == "SUCCESS")

    return ret


def parse_build_matrix(job):
    """ Parse started jobs and result from the matrix of the build job. Usually
        it is only one job, but for some projects we build for multiple arches
        (x86_64, arm) or build multiple times with different configure flags.
        :param job: "build" dict from parse_pipeline()
        :returns: a list of jobs in the matrix, looks like:
                  [{"passed": True, "url": "https://..."}, ...]
    """
    global jenkins_url

    ret = []
    url = f"{job['url']}/consoleFull"
    print(f"Reading {url}")
    with urllib.request.urlopen(url) as response:
        for line in io.TextIOWrapper(response, encoding='utf-8'):
            if " completed with result " in line:
                url = line.split("<a href='", 1)[1].split("'", 1)[0]
                url = f"{jenkins_url}{url}{job['id']}"
                result = line.split(" completed with result ")[1].rstrip()
                passed = result == "SUCCESS"
                ret += [{"passed": passed, "url": url}]
    return ret


def jobs_for_summary(pipeline, build_matrix):
    """ Sort the jobs from pipeline and build matrix into passed/failed lists.
        :returns: a dict that looks like:
                  {"passed": [{"stage": "build", "url": "https://..."}, ...],
                   "failed": [...]} """
    ret = {"passed": [], "failed": []}

    # Build errors are most interesting, display them first
    for job in build_matrix:
        category = "passed" if job["passed"] else "failed"
        ret[category] += [{"stage": "build", "url": job["url"]}]

    # Hide the build matrix job (we show the jobs started by it instead), as
    # long as there is at least one failed started job when the matrix failed
    matrix_failed = "build" in pipeline and not pipeline["build"]["passed"]
    show_build_matrix_job = matrix_failed and not ret["failed"]

    # Add jobs from the pipeline
    for stage, job in pipeline.items():
        if stage == "build" and not show_build_matrix_job:
            continue
        category = "passed" if job["passed"] else "failed"
        ret[category] += [{"stage": stage, "url": job["url"]}]

    return ret


def get_job_short_name(job):
    """ :returns: a short job name, usually the stage (lint, deb, rpm, build).
                  Or in case of build a more useful name like the JOB_TYPE part
                  of the URL if it is found. For osmo-e1-hardware it could be
                  one of: manuals, gateware, firmware, software """
    global re_job_type
    stage = job["stage"]

    if stage == "build":
        match = re_job_type.search(job["url"])
        if match:
            return match.group(1)

    return stage


def get_jobs_list_str(jobs):
    lines = []
    for job in jobs:
        lines += [f"* [{get_job_short_name(job)}] {job['url']}/consoleFull\n"]
    return "".join(sorted(lines))


def get_comment_result(build_url, notify_on_success):
    """ Generate a summary of failed and successful builds for gerrit.
        :returns: a dict that is expected by gerrit's set-review api, e.g.
                  {"tag": "jenkins",
                   "message": "...",
                   "labels": {"Code-Review": -1},
                   "notify": "OWNER"} """
    summary = ""
    pipeline = parse_pipeline(build_url)

    build_matrix = []
    if "build" in pipeline:
        build_matrix = parse_build_matrix(pipeline["build"])

    jobs = jobs_for_summary(pipeline, build_matrix)

    if jobs["failed"]:
        summary += f"{len(jobs['failed'])} failed:\n"
        summary += get_jobs_list_str(jobs["failed"])
        summary += "\n"

    summary += f"{len(jobs['passed'])} passed:\n"
    summary += get_jobs_list_str(jobs["passed"])

    if "build" in pipeline and "deb" in pipeline and "rpm" in pipeline and \
            not pipeline["build"]["passed"] and pipeline["deb"]["passed"] \
            and pipeline["rpm"]["passed"]:
        summary += "\n"
        summary += "The build job(s) failed, but deb/rpm jobs passed.\n"
        summary += "We don't enable external/vty tests when building\n"
        summary += "packages, so maybe those failed. Check the logs.\n"

    if "lint" in pipeline and not pipeline["lint"]["passed"]:
        summary += "\n"
        summary += "Please fix the linting errors. More information:\n"
        summary += "https://osmocom.org/projects/cellular-infrastructure/wiki/Linting\n"

    summary += "\n"
    if jobs["failed"]:
        summary += "Build Failed\n"
        summary += "\n"
        summary += f"Find the Retrigger button here:\n{build_url}\n"
        vote = -1
        notify = "OWNER"
    else:
        summary += "Build Successful\n"
        vote = 1
        notify = "OWNER" if notify_on_success else "NONE"

    # Reference:
    # https://gerrit-review.googlesource.com/Documentation/rest-api-changes.html#set-review
    # https://gerrit-review.googlesource.com/Documentation/rest-api-changes.html#review-input
    return {"tag": "jenkins",
            "message": summary,
            "labels": {"Verified": vote},
            "notify": notify}


def get_comment_start(build_url):
    return {"tag": "jenkins",
            "message": f"Build Started\n{build_url}consoleFull",
            "notify": "NONE"}


def main():
    args = parse_args()
    if args.type == "result":
        comment = get_comment_result(args.build_url, args.notify_on_success)
    else:
        comment = get_comment_start(args.build_url)

    print()
    print(comment["message"])
    print(f"notify: {comment['notify']}")

    if args.output:
        with open(args.output, "w") as handle:
            json.dump(comment, handle, indent=4)

if __name__ == "__main__":
    main()
