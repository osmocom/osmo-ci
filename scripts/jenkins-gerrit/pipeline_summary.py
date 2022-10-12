#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import argparse
import io
import json
import re
import urllib.request

jenkins_url = "https://jenkins.osmocom.org"
re_start_build = re.compile("Starting building: gerrit-[a-zA-Z-_0-9]* #[0-9]*")
re_result = re.compile("^PIPELINE_[A-Z]*_PASSED=[01]$")

def parse_args():
    parser = argparse.ArgumentParser(
        description="Get a summary of failed / successful builds from the CI"
                    " pipeline we run for patches submitted to gerrit.")
    parser.add_argument("build_url",
                        help="$BUILD_URL of the pipeline job, e.g."
                             " https://jenkins.osmocom.org/jenkins/job/gerrit-osmo-bsc-nat/17/")
    parser.add_argument("-o", "--output", help="output json file")
    return parser.parse_args()


def stage_from_job_name(job_name):
    if job_name == "gerrit-pipeline-result":
        # The job that runs this script. Don't include it in the summary.
        return None
    if job_name == "gerrit-lint":
        return "lint"
    if job_name == "gerrit-binpkgs-deb":
        return "deb"
    if job_name == "gerrit-binpkgs-rpm":
        return "rpm"
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
    with urllib.request.urlopen(url) as response:
        for line in io.TextIOWrapper(response, encoding='utf-8'):
            # Parse start build lines
            for match in re_start_build.findall(line):
                job_name = match.split(" ")[2]
                job_id = int(match.split(" ")[3].replace("#", ""))
                job_url = f"{jenkins_url}/jenkins/job/{job_name}/{job_id}"
                stage = stage_from_job_name(job_name)
                if stage:
                    ret[stage] = {"url": job_url, "name": job_name, "id": job_id}

            # Parse result lines
            if re_result.match(line):
                stage = line.split("_")[1].lower()
                assert stage in ret, f"found result for stage {stage}, but" \
                        " didn't find where it was started. The" \
                        " re_start_build regex probably needs to be adjusted" \
                        " to match the related gerrit-*-build job."
                passed = line.split("=")[1].rstrip() == "1"
                ret[stage]["passed"] = passed

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


def get_jobs_list_str(jobs):
    ret = ""
    for job in jobs:
        ret += f"  [{job['stage']}] {job['url']}/consoleFull\n"
    return ret


def get_pipeline_summary(build_url):
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

    if "lint" in pipeline and not pipeline["lint"]["passed"]:
        summary += "\n"
        summary += "Please fix the linting errors. More information:\n"
        summary += "https://osmocom.org/projects/cellular-infrastructure/wiki/Linting\n"

    summary += "\n"
    if jobs["failed"]:
        summary += "Build Failed\n"
        vote = -1
        notify = "OWNER"
    else:
        summary += "Build Successful\n"
        vote = 1
        notify = "NONE"

    # Reference:
    # https://gerrit-review.googlesource.com/Documentation/rest-api-changes.html#set-review
    # https://gerrit-review.googlesource.com/Documentation/rest-api-changes.html#review-input
    return {"tag": "jenkins",
            "message": summary,
            "labels": {"Verified": vote},
            "notify": notify}


def main():
    args = parse_args()
    summary = get_pipeline_summary(args.build_url)

    print(summary["message"])

    if args.output:
        with open(args.output, "w") as handle:
            json.dump(summary, handle, indent=4)

if __name__ == "__main__":
    main()
