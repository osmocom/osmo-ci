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

    if feed.endswith("-asan"):
        version = f"{version}~asan0"

    if version_changelog == version:
        return

    print(f"{project}: adding debian/changelog entry ({version_changelog} =>"
          f" {version})")
    changelog_add_entry(project, feed, version)


def add_configure_arg(project, arg):
    """ Add a configure option like --enable-sanitize to the dh_auto_configure
        line, also add the override_dh_auto_configure block if missing. """
    print(f"{project}: adding {arg} to debian/rules")
    rules = f"{lib.git.get_repo_path(project)}/debian/rules"

    override_found = False
    replaced = False

    with open(rules, "r") as f:
        lines = f.readlines()

    for i in range(len(lines)):
        line = lines[i]
        if line.startswith("override_dh_auto_configure:"):
            override_found = True
            continue

        if "dh_auto_configure" not in line:
            continue

        assert override_found
        assert " -- " in line.replace("\t", " ")

        lines[i] = line.replace(" --", f" -- {arg}", 1)
        replaced = True
        break

    if not override_found:
        lines += ["\n",
                  "override_dh_auto_configure:\n",
                  f"\tdh_auto_configure -- {arg}\n"]

    with open(rules, "w") as f:
        f.writelines(lines)


def disable_tests(project):
    """ Add or replace an existing override_dh_auto_test block with one that
        disables the tests. As of writing we need this for osmocom:nightly:asan
        because OBS has ulimit -v hardcoded (OS#5301). """
    print(f"{project}: disabling tests in debian/rules")
    rules = f"{lib.git.get_repo_path(project)}/debian/rules"

    override_found = False
    replaced = False

    with open(rules, "r") as f:
        lines = f.readlines()

    for i in range(len(lines)):
        line = lines[i]
        if line.startswith("override_dh_auto_test:"):
            override_found = True
            continue

        if not override_found:
            continue

        # End of override_dh_auto_test block
        if line != "\n":
            lines[i] = "\n"
            continue

        replaced = True
        break

    if not override_found:
        lines += ["\n",
                  "override_dh_auto_test:\n"]

    with open(rules, "w") as f:
        f.writelines(lines)


def disable_manuals(project):
    """ For osmocom:nightly:asan we need to disable manuals, as the binaries
        built with sanitizer flags can't run in OBS and they would be running
        during generation of VTY references (OS#5301). """
    print(f"{project}: disabling manuals")
    debian = f"{lib.git.get_repo_path(project)}/debian"

    # Remove osmo-gsm-manuals dep
    lib.run_cmd(["sed", "-i", "/osmo-gsm-manuals-dev/d", f"{debian}/control"])

    # Remove debian/*-doc.install
    lib.run_cmd(f"rm -rf {shlex.quote(debian)}/*-doc.install", shell=True)

    # debian/rules: remove --enable-manuals/doxygen, add --disable-doxygen
    lib.run_cmd(["sed", "-i", "s/--enable-manuals//g", f"{debian}/rules"])
    lib.run_cmd(["sed", "-i", "s/--enable-doxygen//g", f"{debian}/rules"])
    add_configure_arg(project, "--disable-doxygen")


def build_source_package(project):
    fix_source_format(project)
    print(f"{project}: building debian source package")
    lib.run_cmd(["dpkg-buildpackage", "-S", "-uc", "-us", "-d"],
                cwd=lib.git.get_repo_path(project))


def move_files_to_output(project):
    path_output = lib.get_output_path(project)
    lib.run_cmd(f"mv *.tar* *.dsc {shlex.quote(path_output)}", shell=True,
                cwd=lib.config.path_cache)
