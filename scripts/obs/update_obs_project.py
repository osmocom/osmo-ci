#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import argparse
import os
import traceback
import lib
import lib.config
import lib.docker
import lib.git
import lib.metapkg
import lib.osc
import lib.srcpkg

srcpkgs_built = {}  # dict of pkgname: version
srcpkgs_skipped = []  # list of pkgnames
srcpkgs_failed_build = []  # list of pkgnames
srcpkgs_failed_upload = []  # list of pkgnames
srcpkgs_updated = []  # list of pkgnames


def parse_packages(packages_arg):
    if packages_arg:
        for package in packages_arg:
            lib.check_package(package)
        return packages_arg

    # Default to all
    ret = []
    ret += lib.config.projects_osmocom
    ret += lib.config.projects_other
    return ret


def build_srcpkg(feed, branch, package, conflict_version, fetch, is_meta_pkg):
    global srcpkgs_built
    global srcpkgs_failed_build

    version = None

    try:
        if is_meta_pkg:
            version = lib.metapkg.build(feed, conflict_version)
        else:
            version = lib.srcpkg.build(package, feed, branch, conflict_version, fetch)
        srcpkgs_built[package] = version
    except Exception as ex:
        traceback.print_exception(type(ex), ex, ex.__traceback__)
        print()
        print(f"{package}: build failed")
        srcpkgs_failed_build += [package]


def is_up_to_date(obs_version, git_latest_version):
    if obs_version == git_latest_version:
        return True

    # e.g. open5gs has "v" infront of version in git tag
    if f"v{obs_version}" == git_latest_version:
        return True

    return False


def build_srcpkg_if_needed(proj, feed, branch, pkgs_remote, package, conflict_version,
                           fetch, is_meta_pkg, skip_up_to_date):
    global srcpkgs_skipped

    if feed in ["master", "latest"]:
        """ Check if we can skip this package by comparing the OBS version with
            the git remote. """
        if is_meta_pkg:
            latest_version = conflict_version if conflict_version else "1.0.0"
        else:
            if feed == "master":
                latest_version = lib.git.get_head_remote(package, branch)
            else:
                latest_version = lib.git.get_latest_tag_remote(package)

        if latest_version is None:
            print(f"{package}: skipping (no git tag found)")
            srcpkgs_skipped += [package]
            return

        if os.path.basename(package) not in pkgs_remote:
            print(f"{package}: building source package (not in OBS)")
        else:
            obs_version = lib.osc.get_package_version(proj, package, feed)
            if is_up_to_date(obs_version, latest_version):
                if skip_up_to_date:
                    print(f"{package}: skipping ({obs_version} is up-to-date)")
                    srcpkgs_skipped += [package]
                    return
                else:
                    print(f"{package}: building source package"
                          f" ({obs_version} is up-to-date, but"
                          " --no-skip-up-to-date is set)")
            else:
                print(f"{package}: building source package (outdated:"
                      f" {latest_version} <=> {obs_version} in OBS)")
    else:
        print(f"{package}: building source package (feed is {feed})")

    build_srcpkg(feed, branch, package, conflict_version, fetch, is_meta_pkg)


def upload_srcpkg(proj, feed, pkgs_remote, package, version):
    if os.path.basename(package) not in pkgs_remote:
        lib.osc.create_package(proj, package)
    lib.osc.update_package(proj, package, version)


def build_srcpkgs(proj, feed, branch, pkgs_remote, packages, conflict_version, fetch,
                  meta, skip_up_to_date):
    print()
    print("### Building source packages ###")
    print()

    if meta:
        build_srcpkg_if_needed(proj, feed, branch, pkgs_remote, f"osmocom-{feed}",
                               conflict_version, fetch, True, skip_up_to_date)

    for package in packages:
        build_srcpkg_if_needed(proj, feed, branch, pkgs_remote, package,
                               conflict_version, fetch, False, skip_up_to_date)


def upload_srcpkgs(proj, feed, pkgs_remote):
    global srcpkgs_built
    global srcpkgs_failed_upload
    global srcpkgs_updated

    srcpkgs_failed_upload = []
    srcpkgs_updated = []

    if not srcpkgs_built:
        return

    print()
    print("### Uploading built packages ###")
    print()

    for package, version in srcpkgs_built.items():
        try:
            upload_srcpkg(proj, feed, pkgs_remote, package, version)
            srcpkgs_updated += [package]
        except Exception as ex:
            traceback.print_exception(type(ex), ex, ex.__traceback__)
            print()
            print(f"{package}: upload failed")
            srcpkgs_failed_upload += [package]


def exit_with_summary():
    global srcpkgs_updated
    global srcpkgs_skipped
    global srcpkgs_failed_build
    global srcpkgs_failed_upload

    print()
    print("### Summary ###")
    print()
    print(f"Updated:                {len(srcpkgs_updated)}")
    print(f"Skipped:                {len(srcpkgs_skipped)}")
    print(f"Failed (srcpkg build):  {len(srcpkgs_failed_build)}")
    print(f"Failed (srcpkg upload): {len(srcpkgs_failed_upload)}")

    if not srcpkgs_failed_build and not srcpkgs_failed_upload:
        exit(0)

    print()
    print("List of failed packages:")
    for package in srcpkgs_failed_build:
        print(f"* {package} (srcpkg build)")
    for package in srcpkgs_failed_upload:
        print(f"* {package} (srcpkg upload)")

    exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Generate source packages and upload them to OBS.")
    lib.add_shared_arguments(parser)
    parser.add_argument("-A", "--apiurl", help="OBS API URL or .oscrc alias"
                        " (e.g. https://obs.osmocom.org)")
    parser.add_argument("-n", "--no-skip-up-to-date",
                        dest="skip_up_to_date", action="store_false",
                        help="for latest feed, build and upload packages even"
                             " if the version did not change")
    parser.add_argument("obs_project",
                        help="OBS project, e.g. home:osmith:nightly")
    parser.add_argument("package", nargs="*",
                        help="package name, e.g. libosmocore or open5gs,"
                             " default is all packages")
    args = parser.parse_args()
    proj = args.obs_project
    feed = args.feed
    branch = args.git_branch
    packages = parse_packages(args.package)

    lib.set_cmds_verbose(args.verbose)

    if args.docker:
        lib.docker.run_in_docker_and_exit("update_obs_project.py", True)

    lib.osc.check_proj(proj)
    lib.osc.check_oscrc()
    lib.osc.set_apiurl(args.apiurl)

    if not args.ignore_req:
        lib.check_required_programs()

    lib.remove_temp()

    pkgs_remote = lib.osc.get_remote_pkgs(proj)

    build_srcpkgs(proj, feed, branch, pkgs_remote, packages, args.conflict_version,
                  args.git_fetch, args.meta, args.skip_up_to_date)
    upload_srcpkgs(proj, feed, pkgs_remote)
    exit_with_summary()


if __name__ == "__main__":
    main()
