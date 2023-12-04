#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2023 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import argparse
import lib.docker
import lib.osc
import sys

projects_opensuse = None
projects_osmocom = None


def parse_args():
    parser = argparse.ArgumentParser(description="Check for new distribution"
        " projects on the openSUSE OBS, that we want to configure in the"
        " Osmocom OBS as soon as they are available")
    parser.add_argument("-d", "--docker",
                        help="run in docker to avoid installing required pkgs",
                        action="store_true")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="always print shell commands and their output,"
                             " instead of only printing them on error")

    advanced = parser.add_argument_group("advanced options")
    advanced.add_argument("-A", "--apiurl", help="source OBS API URL"
                          " (default: https://api.opensuse.org)",
                          default="https://api.opensuse.org")
    advanced.add_argument("-p", "--prefix", default="openSUSE.org-mirror",
                          help="destination OBS prefix"
                               " (default: openSUSE.org-mirror)")
    advanced.add_argument("-t", "--to-apiurl", help="destination OBS API URL"
                          " (default: https://obs.osmocom.org)",
                          default="https://obs.osmocom.org")

    args = parser.parse_args()
    lib.set_args(args)

    lib.osc.check_oscrc()

    if args.docker:
        lib.docker.run_in_docker_and_exit("check_new_distros.py", add_oscrc=True)


def find_highest_distro_project(distro):
    highest = None
    for project in projects_opensuse:
        if not project.startswith(f"{distro}:"):
            continue

        num = project[len(distro) + 1:]
        if not lib.config.check_new_distros_version_regex.match(num):
            if lib.args.verbose:
                print(f"ignoring {distro}:{num} (doesn't match version regex)")
            continue

        if not highest or float(num) > float(highest):
            highest = num

    if highest:
        return f"{distro}:{highest}"

    return None


def check_distro(distro):
    highest = find_highest_distro_project(distro)
    if not highest:
        print(f"ERROR: {distro}: not found in {lib.args.apiurl}")
        return False

    # check if it is in the osmo obs
    exp = f"{lib.args.prefix}:{highest}"
    if exp in projects_osmocom:
        print(f"{exp}: OK")
        return True

    print()
    print(f"ERROR: {exp} not found")
    print()
    print("Follow this guide to add it to the Osmocom OBS:")
    print("https://osmocom.org/projects/cellular-infrastructure/wiki/Add_a_new_distribution_to_OBS")
    print()

    return False


def main():
    global projects_opensuse
    global projects_osmocom

    parse_args()
    ret = 0

    # Get list of projects from Osmocom OBS
    lib.osc.set_apiurl(lib.args.to_apiurl)
    projects_osmocom = lib.osc.get_projects()

    # Get list of projects from openSUSE OBS
    lib.osc.set_apiurl(lib.args.apiurl)
    projects_opensuse = lib.osc.get_projects()

    # Check for missing distros in Osmocom OBS
    for distro in lib.config.check_new_distros:
        if not check_distro(distro):
            ret = 1

    sys.exit(ret)

if __name__ == "__main__":
    main()
