#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import datetime
import os
import shlex
import lib
import lib.git


def control_add_depend(project, pkgname, version):
    """ :param pkgname: of the meta-package to depend on (e.g. osmocom-nightly)
        :param version: of the meta-pkgname to depend on or None """
    repo_path = lib.git.get_repo_path(project)

    if version:
        depend = f"{pkgname} (= {version})"
    else:
        depend = pkgname

    cmd = ["sed", f"s/^Depends: /Depends: {depend}, /", "-i", "debian/control"]
    lib.run_cmd(cmd, cwd=repo_path)


def changelog_add_entry(project, feed, version):
    """ :param version: for the new changelog entry """
    repo_path = lib.git.get_repo_path(project)
    changelog_path = f"{repo_path}/debian/changelog"

    changelog_old = open(changelog_path).read()

    # Package name might be different from project name, read it from changelog
    pkgname = changelog_old.split(" ", 1)[0]
    assert pkgname

    # Debian doesn't allow '-' in version
    version = version.replace("-", ".")

    # Debian changelog requires this specific date format
    date = datetime.datetime.now(datetime.timezone.utc)
    date_str = date.strftime("%a, %d %b %Y %H:%M:%S %z")

    # Add new changelog entry
    with open(changelog_path, "w") as f:
        f.write(f"{pkgname} ({version}) unstable; urgency=medium\n")
        f.write("\n")
        f.write("  * Automatically generated changelog entry for building the"
                f" Osmocom {feed} feed\n")
        f.write("\n")
        f.write(f" -- Osmocom OBS scripts <info@osmocom.org>  {date_str}\n")
        f.write("\n")
        f.write(changelog_old)


def fix_source_format(project):
    """ Always use format "3.0 (native)" (e.g. limesuite has "3.0 (quilt)")."""
    repo_path = lib.git.get_repo_path(project)
    format_path = f"{repo_path}/debian/source/format"
    if not os.path.exists(format_path):
        return

    expected = "3.0 (native)\n"
    current = open(format_path, "r").read()

    if current == expected:
        return

    print(f"{project}: fixing debian/source/format ({current.rstrip()} =>"
          f" {expected.rstrip()})")
    open(format_path, "w").write(expected)


def get_last_version_from_changelog(project):
    repo_path = lib.git.get_repo_path(project)
    changelog_path = f"{repo_path}/debian/changelog"

    if not os.path.exists(changelog_path):
        return None

    changelog = open(changelog_path).read()
    if not changelog:
        return None

    return changelog.split("(", 1)[1].split(")", 1)[0]


def changelog_add_entry_if_needed(project, feed, version):
    """ Adjust the changelog if the version in the changelog is different from
        the given version. """
    version_changelog = get_last_version_from_changelog(project)
    if version_changelog == version:
        return

    print(f"{project}: adding debian/changelog entry ({version_changelog} =>"
          f" {version})")
    changelog_add_entry(project, feed, version)


def build_source_package(project):
    fix_source_format(project)
    print(f"{project}: building debian source package")
    lib.run_cmd(["dpkg-buildpackage", "-S", "-uc", "-us", "-d"],
                cwd=lib.git.get_repo_path(project))


def move_files_to_output(project):
    path_output = lib.get_output_path(project)
    lib.run_cmd(f"mv *.tar* *.dsc {shlex.quote(path_output)}", shell=True,
                cwd=lib.config.path_cache)
