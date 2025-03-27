#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2025 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import argparse
import fnmatch
import hashlib
import lib
import lib.osc
import os
import sys
import time

# Only delete files that were created by the Osmocom_OBS_* jenkins jobs
safe_to_delete_patterns = [
    "*.dsc",
    "*.tar.xz",
]

cache_dir = os.path.expanduser("~/.cache/osmo_ci_obs_cleanup")


def parse_args():
    parser = argparse.ArgumentParser(description="Clean up old sources to free up space.")

    parser.add_argument("-P", "--project", help="optional path to a specific project (e.g. osmocom:master)")

    parser.add_argument("-p", "--package", help="optional path to a specific package (e.g. osmo-mgw)")

    parser.add_argument("-k", "--keep-revisions", type=int, default=5, help="how many revisions to keep (default: 5)")

    parser.add_argument(
        "-s", "--sleep", type=int, default=0, help="how many seconds to sleep between queries (default: 0)"
    )

    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="always print shell commands and their output, instead of only printing them on error",
    )
    parser.add_argument(
        "-A",
        "--apiurl",
        help="OBS API URL or .oscrc alias (default: https://obs.osmocom.org)",
        default="https://obs.osmocom.org",
    )

    args = parser.parse_args()
    lib.set_args(args)
    lib.osc.set_apiurl(args.apiurl)


def sleep():
    if lib.args.sleep != 0:
        time.sleep(lib.args.sleep)


def get_projects():
    if lib.args.project:
        return [lib.args.project]
    return lib.osc.get_projects()


def get_packages(project):
    if lib.args.package:
        return [lib.args.package]
    sleep()
    return lib.osc.get_remote_pkgs()


def check_safe_to_delete(source):
    for pattern in safe_to_delete_patterns:
        if fnmatch.fnmatch(source, pattern):
            return True
    return False


def get_start_rev_file(project, package):
    h = hashlib.new("sha512")
    h.update(f"{project}/{package}".encode())
    return f"{cache_dir}/{h.hexdigest()}"


def get_start_rev(project, package):
    f = get_start_rev_file(project, package)
    if not os.path.exists(f):
        return 0

    with open(f, "r") as h:
        return int(h.read().rstrip())


def set_start_rev(project, package, rev):
    f = get_start_rev_file(project, package)
    with open(f, "w") as h:
        h.write(f"{rev}\n")


def clean_package(project, package):
    sleep()
    last_rev = lib.osc.get_last_rev(package)
    if last_rev <= lib.args.keep_revisions:
        return

    sleep()
    sources_current = lib.osc.get_package_sources(package, last_rev)

    start = get_start_rev(project, package) + 1
    end = last_rev - lib.args.keep_revisions + 1
    for rev in range(start, end):
        print(f"     checking rev {rev}/{last_rev}")
        sleep()
        sources_rev = lib.osc.get_package_sources(package, rev)
        for source in sources_rev:
            if source not in sources_current:
                assert "/" not in package
                assert "/" not in source
                path = f"/srv/obs/sources/{package}/{source}"
                if check_safe_to_delete(source):
                    if os.path.exists(path) and os.path.getsize(path) != 0:
                        print(f"       rm {source}")
                        lib.run_cmd(["rm", path])
                    # Leave empty dummy files behind, so OBS doensn't throw 50x
                    # errors (SYS#7407#note-8)
                    if not os.path.exists(path):
                        print(f"       touch {source}")
                        lib.run_cmd(["touch", path])
        set_start_rev(project, package, rev)


def main():
    if not os.path.exists("/srv/obs/sources"):
        print("ERROR: this script needs to run on an OBS server!")
        sys.exit(1)

    lib.run_cmd(["mkdir", "-p", cache_dir])

    parse_args()
    lib.osc.check_oscrc()

    for project in get_projects():
        if ":" not in project:
            continue

        lib.osc.set_apiurl(lib.args.apiurl, project)

        packages = get_packages(project)
        if len(packages) == 1 and packages[0] == "":
            continue

        for package in packages:
            clean_package(project, package)


if __name__ == "__main__":
    main()
    print("Success")
