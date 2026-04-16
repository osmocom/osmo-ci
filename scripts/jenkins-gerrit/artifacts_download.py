#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2026 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import argparse
import io
import re
import shutil
import sys
import urllib.request
import zipfile
import os

jenkins_url = "https://jenkins.osmocom.org"
re_start_build = re.compile("Starting building: gerrit-[a-zA-Z-_0-9]* #[0-9]*")
matrix = "a1=default,a2=default,a3=default,a4=default,label=osmocom-gerrit"


def parse_args():
    parser = argparse.ArgumentParser(description="Download artifacts from the gerrit pipeline.")
    parser.add_argument(
        "pipeline_url",
        help="$BUILD_URL of the pipeline job, e.g."
        " https://jenkins.osmocom.org/jenkins/job/gerrit-osmo-ccid-firmware/177/",
    )
    return parser.parse_args()


def get_job_url(pipeline_url):
    url = f"{pipeline_url}/consoleText"
    print(f"GET {url}")
    with urllib.request.urlopen(url) as response:
        for line in io.TextIOWrapper(response, encoding="utf-8"):
            for match in re_start_build.findall(line):
                job_name = match.split(" ")[2]
                if not job_name.endswith("-build"):
                    continue
                job_id = int(match.split(" ")[3].replace("#", ""))
                job_url = f"{jenkins_url}/jenkins/job/{job_name}/{matrix}/{job_id}"
                return job_url

    print("ERROR: failed to find job URL!")
    sys.exit(1)


def download_archive_zip(job_url):
    url = f"{job_url}/artifact/*zip*/archive.zip"
    print(f"GET {url}")
    with urllib.request.urlopen(url) as response, open("archive.zip", "wb") as handle:
        shutil.copyfileobj(response, handle)


def extract_archive_zip():
    path = os.path.join(os.getcwd(), "gerrit-artifacts")
    os.makedirs(path)
    print(f"UNZIP archive.zip to {path}")
    with zipfile.ZipFile("archive.zip") as z:
        z.extractall(path)


def main():
    args = parse_args()
    job_url = get_job_url(args.pipeline_url)
    download_archive_zip(job_url)
    extract_archive_zip()


if __name__ == "__main__":
    main()
