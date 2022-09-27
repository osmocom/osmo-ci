#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import argparse
import lib
import lib.config
import lib.docker
import lib.git
import lib.metapkg
import lib.srcpkg


def main():
    parser = argparse.ArgumentParser(
        description="Clone the git repository and build the debian source"
                    " package as well as an rpm .spec file. This is the same"
                    " code that runs to generate source packages which we"
                    " upload to https://obs.osmocom.org."
                    f" Output dir: {lib.config.path_temp}/srcpkgs")
    lib.add_shared_arguments(parser)
    parser.add_argument("-g", "--gerrit-id", type=int, default=0,
                        help="clone particular revision from gerrit using given ID")
    parser.add_argument("package", nargs="?",
                        help="package name, e.g. libosmocore or open5gs")
    args = parser.parse_args()

    if not args.meta and not args.package:
        print("ERROR: specify -m and/or a package. See -h for help.")
        exit(1)

    lib.set_cmds_verbose(args.verbose)

    if args.docker:
        lib.docker.run_in_docker_and_exit(__file__)

    if not args.ignore_req:
        lib.check_required_programs()

    if args.package:
        lib.check_package(args.package)
    lib.remove_temp()

    if args.meta:
        lib.metapkg.build(args.feed, args.conflict_version)

    if args.package:
        lib.srcpkg.build(args.package, args.feed, args.git_branch, args.conflict_version,
                         args.git_fetch, args.gerrit_id)


if __name__ == "__main__":
    main()
