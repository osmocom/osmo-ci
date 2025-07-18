#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import argparse
import os
import sys
import traceback
import lib
import lib.config
import lib.debian
import lib.docker
import lib.git
import lib.metapkg
import lib.osc
import lib.srcpkg

srcpkgs_built = {}  # dict of pkgname: version
srcpkgs_skipped = []  # list of pkgnames
srcpkgs_deleted = []  # list of pkgnames
srcpkgs_failed_build = []  # list of pkgnames
srcpkgs_failed_upload = []  # list of pkgnames
srcpkgs_updated = []  # list of pkgnames


def parse_packages(packages_arg, excludes_arg):
    ret = []
    if packages_arg:
        for package in packages_arg:
            if package == "ALL_OSMOCOM_PACKAGES":
                ret += lib.config.projects_osmocom
            else:
                ret += [lib.set_proper_package_name(package)]
    else:  # Default to all
        ret += lib.config.projects_osmocom
        ret += lib.config.projects_other

    # Apply --exclude-package
    for package in excludes_arg:
        if package in ret:
            ret.remove(package)

    return ret


def build_srcpkg(package, is_meta_pkg):
    global srcpkgs_built
    global srcpkgs_failed_build

    version = None

    try:
        if is_meta_pkg:
            version = lib.metapkg.build()
        else:
            version = lib.srcpkg.build(package)
        srcpkgs_built[package] = version
    except Exception as ex:
        traceback.print_exception(type(ex), ex, ex.__traceback__)
        print()
        print(f"{package}: build failed")
        srcpkgs_failed_build += [package]


def delete_srcpkg(package):
    global srcpkgs_deleted
    branch = lib.args.git_branch

    lib.osc.delete_package(package, f"branch {branch} does not exist anymore")
    srcpkgs_deleted += [package]


def is_up_to_date(obs_version, git_latest_version):
    if obs_version == git_latest_version:
        return True

    # e.g. open5gs has "v" infront of version in git tag
    if f"v{obs_version}" == git_latest_version:
        return True

    return False


def build_srcpkg_if_needed(pkgs_remote, package, is_meta_pkg):
    global srcpkgs_skipped
    feed = lib.args.feed
    branch = lib.args.git_branch
    delete = lib.args.delete

    if feed in ["master", "latest"]:
        """ Check if we can skip this package by comparing the OBS version with
            the git remote. """
        if is_meta_pkg:
            conflict_version = lib.args.conflict_version
            latest_version = conflict_version if conflict_version else lib.config.meta_package_version
        else:
            if feed == "master":
                latest_version = lib.git.get_head_remote(package, branch,
                    branch_missing_ok=delete)
            else:
                latest_version = lib.git.get_latest_tag_remote(package)
                latest_version = lib.debian.transform_version(latest_version)

        if latest_version is None:
            if delete and os.path.basename(package) in pkgs_remote:
                delete_srcpkg(package)
                return

            print(f"{package}: skipping (no git tag/branch found)")
            srcpkgs_skipped += [package]
            return

        if os.path.basename(package) not in pkgs_remote:
            print(f"{package}: building source package (not in OBS)")
        else:
            obs_version = lib.osc.get_package_version(package)
            if is_up_to_date(obs_version, latest_version):
                if lib.args.skip_up_to_date:
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

    build_srcpkg(package, is_meta_pkg)


def upload_srcpkg(pkgs_remote, package, version):
    if os.path.basename(package) not in pkgs_remote:
        lib.osc.create_package(package)
    lib.osc.update_package(package, version)


def build_srcpkgs(pkgs_remote, packages):
    print()
    print("### Building source packages ###")
    print()

    if lib.args.meta:
        feed = lib.args.feed
        metapkg = lib.args.conflict_pkgname or f"osmocom-{feed}"
        build_srcpkg_if_needed(pkgs_remote, metapkg, True)

    for package in packages:
        build_srcpkg_if_needed(pkgs_remote, package, False)


def upload_srcpkgs(pkgs_remote):
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
            upload_srcpkg(pkgs_remote, package, version)
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
    print(f"Deleted:                {len(srcpkgs_deleted)}")

    if not srcpkgs_failed_build and not srcpkgs_failed_upload:
        sys.exit(0)

    print()
    print("List of failed packages:")
    for package in srcpkgs_failed_build:
        print(f"* {package} (srcpkg build)")
    for package in srcpkgs_failed_upload:
        print(f"* {package} (srcpkg upload)")

    sys.exit(1)


def validate_args(args):
    # Only with feed=master we check the current commit of a branch on a remote
    # git repository before trying to update/delete a package from OBS
    if args.delete and args.feed != "master":
        print("ERROR: --delete can only be used with --feed=master")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Generate source packages and upload them to OBS.")
    groups = lib.add_shared_arguments(parser)

    groups["pkg"].add_argument("-E", "--exclude-package", nargs="*",
                               default=[],
                               help="do not build and update this package")

    group_obs = parser.add_argument_group("OBS options")
    group_obs.add_argument("-A", "--apiurl", help="OBS API URL or .oscrc alias"
                           " (e.g. https://obs.osmocom.org)")
    group_obs.add_argument("-n", "--no-skip-up-to-date",
                           dest="skip_up_to_date", action="store_false",
                           help="for latest feed, build and upload packages"
                                " even if the version did not change")
    group_obs.add_argument("--delete", action="store_true",
                           help="remove packages from OBS if the git branch"
                                " (-b) does not exist anymore")

    parser.add_argument("obs_project",
                        help="OBS project, e.g. home:osmith:nightly")
    parser.add_argument("package", nargs="*",
                        help="package name, e.g. libosmocore or open5gs or"
                             " ALL_OSMOCOM_PACKAGES, default is all packages")
    args = parser.parse_args()
    validate_args(args)
    lib.set_args(args)
    packages = parse_packages(args.package, args.exclude_package)

    if args.docker:
        lib.docker.run_in_docker_and_exit("update_obs_project.py", True)

    lib.osc.check_oscrc()
    lib.osc.set_apiurl(args.apiurl, args.obs_project)

    if not args.ignore_req:
        lib.check_required_programs()

    lib.remove_temp()

    pkgs_remote = lib.osc.get_remote_pkgs()

    build_srcpkgs(pkgs_remote, packages)
    upload_srcpkgs(pkgs_remote)
    exit_with_summary()


if __name__ == "__main__":
    main()
