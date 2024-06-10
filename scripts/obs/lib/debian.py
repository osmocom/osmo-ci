#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import datetime
import os
import shlex
import lib
import lib.git

# Imports that may not be available during startup, ignore it here and rely on
# lib.check_required_programs() checking this later on (possibly after the
# script executed itself in docker if using --docker).
try:
    import packaging.version
except ImportError:
    pass

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


def changelog_add_entry(project, version):
    """ :param version: for the new changelog entry """
    feed = lib.args.feed
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

    expected = "3.0 (native)"
    current = open(format_path, "r").read().rstrip()

    if current == expected:
        return

    print(f"{project}: fixing debian/source/format ({current} => {expected})")
    open(format_path, "w").write(f"{expected}\n")


def get_last_version_from_changelog(project):
    repo_path = lib.git.get_repo_path(project)
    changelog_path = f"{repo_path}/debian/changelog"

    assert os.path.exists(changelog_path), f"{project}: missing debian/changelog"

    changelog = open(changelog_path).read()
    assert changelog, f"{project}: debian/changelog is empty"

    ret = changelog.split("(", 1)[1].split(")", 1)[0]
    assert ret, f"{project}: couldn't find last version in debian/changelog"

    return ret


def changelog_add_entry_if_needed(project, version):
    """ Adjust the changelog if the version in the changelog is different from
        the given version. """
    version_changelog = get_last_version_from_changelog(project)

    # Don't use a lower number (OS#6173)
    try:
        if packaging.version.parse(version_changelog.split("-")[0]) > \
                packaging.version.parse(version.split("-")[0]):
            print(f"{project}: WARNING: version from changelog"
                  f" ({version_changelog}) is higher than version based on git tag"
                  f" ({version}), using version from changelog (git tag not pushed"
                  " yet?)")
            return
    except packaging.version.InvalidVersion:
        # packaging.version.parse can parse the version numbers used in Osmocom
        # projects (where we need the above check), but not e.g. some versions
        # from wireshark. Don't abort here if that is the case.
        pass

    if version_changelog == version:
        return

    print(f"{project}: adding debian/changelog entry ({version_changelog} =>"
          f" {version})")
    changelog_add_entry(project, version)


def configure_append(project, parameters):
    """ Add one or more configure parameters like --enable-sanitize to the
        dh_auto_configure line, also add the override_dh_auto_configure block
        if missing. """
    print(f"{project}: adding configure parameters: {parameters}")
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
        if " -- " in line.replace("\t", " "):
            lines[i] = line.replace(" --", f" -- {parameters}", 1)
        else:
            lines[i] = line.replace("dh_auto_configure",
                                    f"dh_auto_configure -- {parameters}", 1)
        replaced = True
        break
    if not override_found:
        lines += ["\n",
                  "override_dh_auto_configure:\n",
                  f"\tdh_auto_configure -- {parameters}\n"]
    with open(rules, "w") as f:
        f.writelines(lines)


def disable_manuals(project):
    """ Disabling manuals speeds up the build time significantly, we don't
        need them for e.g. the asan repository. """
    print(f"{project}: disabling manuals")
    debian = f"{lib.git.get_repo_path(project)}/debian"
    # Remove dependencies
    lib.run_cmd(["sed", "-i", "/osmo-gsm-manuals-dev/d", f"{debian}/control"])
    lib.run_cmd(["sed", "-i", "/doxygen/d", f"{debian}/control"])
    # Remove debian/*-doc.install
    lib.run_cmd(f"rm -rf {shlex.quote(debian)}/*-doc.install", shell=True)
    # debian/rules: remove --enable-manuals/doxygen, add --disable-doxygen
    lib.run_cmd(["sed", "-i", "s/--enable-manuals//g", f"{debian}/rules"])
    lib.run_cmd(["sed", "-i", "s/--enable-doxygen//g", f"{debian}/rules"])


def build_source_package(project):
    fix_source_format(project)
    print(f"{project}: building debian source package")
    lib.run_cmd(["dpkg-buildpackage", "-S", "-uc", "-us", "-d"],
                cwd=lib.git.get_repo_path(project))


def move_files_to_output(project):
    path_output = lib.get_output_path(project)
    lib.run_cmd(f"mv *.tar* *.dsc {shlex.quote(path_output)}", shell=True,
                cwd=lib.config.path_cache)
