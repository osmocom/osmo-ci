#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2018 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>

import argparse
import os
import shutil
import sys

# Same folder
import config
import dependencies
import buildstack


def parse_arguments():
    # Create argparser
    description = ("This script verifies that Osmocom programs really build"
                   " with the dependency versions they claim to support in"
                   " configure.ac. In order to do that, it clones the"
                   " dependency repositories if they don't exist in workdir"
                   " already, and checks out the minimum version tag. This"
                   " happens recursively for their dependencies as well.")
    parser = argparse.ArgumentParser(description=description)

    # Git sources folder
    workdir_default = os.path.expanduser("~") + "/osmo-depcheck-work"
    parser.add_argument("-w", "--workdir", default=workdir_default,
                        help="folder to which the sources will be cloned"
                             " (default: " + workdir_default + ")")

    # Build switch
    parser.add_argument("-b", "--build", action="store_true",
                        help="don't only parse the dependencies, but also try"
                             " to build the program")

    # Build switch
    parser.add_argument("-o", "--old", action="store_true",
                        help="report dependencies on old releases")

    # Job count
    parser.add_argument("-j", "--jobs", type=int,
                        help="parallel build jobs (for make)")

    # Git URL prefix
    parser.add_argument("-u", "--git-url-prefix", dest="prefix",
                        default=config.git_url_prefix,
                        help="where to clone the sources from (default: " +
                             config.git_url_prefix + ")")

    # Projects
    parser.add_argument("projects_revs", nargs="*", default=config.projects,
                        help="which Osmocom projects to look at"
                             " (e.g. 'osmo-hlr:0.2.1', 'osmo-bts', defaults to"
                             " all projects defined in config.py, default"
                             " revision is 'master')",
                        metavar="project[:revision]")

    # Workdir must exist
    ret = parser.parse_args()
    if not os.path.exists(ret.workdir):
        print("ERROR: workdir does not exist: " + ret.workdir)
        sys.exit(1)
    return ret


def workdir_prepare(workdir):
    """ Delete old binaries and create the subfolders in workdir
        :param workdir: path to where all data is stored """
    # Delete folders with binaries from previous runs
    for subfolder in ("build", "install"):
        full = workdir + "/" + subfolder
        if os.path.exists(full):
            shutil.rmtree(full)

    # Create all subfolders
    for subfolder in ("build", "install", "git"):
        os.makedirs(workdir + "/" + subfolder, exist_ok=True)


def main():
    args = parse_arguments()

    # Iterate over projects
    cache_git_fetch = []
    for project_rev in args.projects_revs:
        # Split the git revision from the project name
        project = project_rev
        rev = "master"
        if ":" in project_rev:
            project, rev = project_rev.split(":", 1)

        # Clone and parse the repositories
        workdir_prepare(args.workdir)
        depends = dependencies.generate(args.workdir, args.prefix,
                                        cache_git_fetch, project, rev)
        print("---")
        dependencies.print_dict(depends)
        stack = buildstack.generate(depends)
        print("---")
        buildstack.print_dict(stack)

        # Old versions
        if args.old:
            print("---")
            dependencies.print_old(args.workdir, depends)

        # Build
        if args.build:
            print("---")
            buildstack.build(args.workdir, args.jobs, stack)

        # Success
        print("---")
        print("Success for " + project + ":" + rev + "!")
        print("---")


if __name__ == '__main__':
    main()
