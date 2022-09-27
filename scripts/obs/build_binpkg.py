#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import argparse
import multiprocessing
import os
import lib
import lib.binpkg_deb
import lib.config
import lib.docker
import lib.git
import lib.metapkg
import lib.srcpkg


def main():
    distro_default = lib.config.docker_distro_default
    distro_choices = [distro_default] + lib.config.docker_distro_other
    jobs_default = multiprocessing.cpu_count() + 1

    parser = argparse.ArgumentParser(
        description="Build a deb or rpm package as it would be done on"
                    " obs.osmocom.org. Use after building a source package"
                    " with build_srcpkg.py."
                    f" Output dir: {lib.config.path_temp}/binpkgs")
    parser.add_argument("-d", "--docker", choices=distro_choices,
                        const=distro_default, nargs="?",
                        help="build the package in docker for a specific"
                             f" distro (default: {distro_default})")
    parser.add_argument("-j", "--jobs", type=int, default=jobs_default,
                        help=f"parallel running jobs (default: {jobs_default})")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="always print shell commands and their output,"
                             " instead of only printing them on error")
    parser.add_argument("package",
                        help="package name, e.g. libosmocore")
    args = parser.parse_args()

    lib.set_cmds_verbose(args.verbose)

    srcdir = f"{lib.config.path_temp}/srcpkgs/{args.package}"
    if not os.path.exists(srcdir):
        print(f"ERROR: {args.package}: no srcpkg found, run build_srcpkg.py"
              " first!")
        exit(1)

    bindir = f"{lib.config.path_temp}/binpkgs"
    lib.run_cmd(["rm", "-rf", bindir])
    os.makedirs(bindir)

    distro = args.docker if args.docker else distro_default

    env = {"JOBS": str(args.jobs),
           "PACKAGE": args.package,
           "BUILDUSER": os.environ["USER"]}

    script_path = "data/build_deb.sh"
    if not distro.startswith("debian:"):
        script_path = "data/build_rpm.sh"

    if args.docker:
        image_type = "build_binpkg"

        # Optimization: use docker container with osmo-gsm-manuals-dev already
        # installed if it is in build depends
        if distro.startswith("debian:") \
                and lib.srcpkg.requires_osmo_gsm_manuals_dev(args.package):
            image_type += "_manuals"

        env["BUILDUSER"] = "user"
        lib.docker.run_in_docker_and_exit(script_path,
                                          image_type=image_type,
                                          distro=distro,
                                          pass_argv=False, env=env)
    else:
        lib.run_cmd(["sudo", "-E", script_path], env=env,
                    cwd=lib.config.path_top)

if __name__ == "__main__":
    main()
