#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import os
import pathlib
import lib.config
import lib.debian
import lib.rpm_spec


def checkout_for_feed(project, feed, branch=None):
    """ checkout a commit, either latest tag or master or 20YY branch """
    if branch:
        lib.git.checkout(project, f"origin/{branch}")
    elif feed == "latest":
        lib.git.checkout_latest_tag(project)
    elif feed in ["master", "nightly"]:
        lib.git.checkout_default_branch(project)
    else:  # 2022q1 etc
        lib.git.checkout(project, f"origin/{feed}")


def get_git_version_gen_path(project):
    # Use git-version-gen in the project's repository if available
    repo_path = lib.git.get_repo_path(project)
    ret = f"{repo_path}/git-version-gen"
    if os.path.exists(ret):
        return ret

    # Use git-version-gen script from libosmocore.git as fallback
    print(f"{project}: has no git-version-gen, using the one from libosmocore")
    repo_path = lib.git.get_repo_path("libosmocore")
    ret = f"{repo_path}/git-version-gen"
    if not os.path.exists(ret):
        lib.git.clone("libosmocore")
    if os.path.exists(ret):
        return ret

    print(f"ERROR: {project}.git doesn't have a git-version-gen script and"
          " couldn't find libosmocore.git's copy of the script here either: "
          + ret)
    exit(1)


def get_git_version(project):
    """ :returns: the string from git-version-gen, e.g. '1.7.0.10-76bdb' """
    repo_path = lib.git.get_repo_path(project)
    script_path = get_git_version_gen_path(project)

    ret = lib.run_cmd([script_path, "."], cwd=repo_path)
    if not ret.output:
        lib.exit_error_cmd(ret, "empty output from git-version-gen")

    return ret.output


def get_version_for_feed(project, feed, conflict_version):
    if feed == "latest":
        # There's always a tag if we are here. If there was none, the build
        # would have been skipped for latest.
        ret = lib.git.get_latest_tag(project)
        return ret[1:] if ret.startswith("v") else ret

    ret = get_git_version(project)

    # Try to get the last version from the debian/changelog if we can't get
    # it with git-version-gen, like it was done in the previous OBS scripts
    if ret == "UNKNOWN":
        ret = lib.debian.get_last_version_from_changelog(project)
        # cut off epoch, we retrieve it separately in get_epoch() below
        if ":" in ret:
            ret = ret.split(":")[1]

    # Append the conflict_version to increase the version even if the commit
    # did not change (OS#5135)
    if conflict_version:
        ret = f"{ret}.{conflict_version}"

    return ret


def get_epoch(project):
    """ The osmo-gbproxy used to have the same package version as osmo-sgsn
        until 2021 where it was split into its own git repository. From then
        on, osmo-gbproxy has a 0.*.* package version, which is smaller than
        the previous 1.*.* from osmo-sgsn. We had to set the epoch to 1 for
        osmo-gbproxy so package managers know these 0.*.* versions are higher
        than the previous 1.*.* ones that are still found in e.g. debian 11.
        The epoch is set in debian/changelog, retrieve it from there.
        :returns: the epoch number if set, e.g. "1" or an empty string """
    version_epoch = lib.debian.get_last_version_from_changelog(project)

    if ":" in version_epoch:
        return version_epoch.split(":")[0]

    return ""


def prepare_project_osmo_dia2gsup():
    """ Run erlang/osmo_dia2gsup's generate_build_dep.sh script to download
        sources for dependencies. """
    lib.run_cmd("contrib/generate_build_dep.sh",
                cwd=lib.git.get_repo_path("erlang/osmo_dia2gsup"))


def prepare_project_open5gs():
    """ Build fails without downloading freeDiameter sources. Also we can't
        just update all subprojects because it would fail with 'Subproject
        exists but has no meson.build file' for promethous-client-c. """
    lib.run_cmd(["meson", "subprojects", "download", "freeDiameter"],
                cwd=lib.git.get_repo_path("open5gs"))


def write_tarball_version(project, version):
    repo_path = lib.git.get_repo_path(project)

    with open(f"{repo_path}/.tarball-version", "w") as f:
        f.write(f"{version}\n")


def write_commit_txt(project):
    """ Write the current git commit to commit_$commit.txt file, so it gets
        uploaded to OBS along with the rest of the source package. This allows
        figuring out if the source package is still up-to-date or not for the
        master feed. """
    output_path = lib.get_output_path(project)
    commit = lib.git.get_head(project)

    print(f"{project}: adding commit_{commit}.txt")
    pathlib.Path(f"{output_path}/commit_{commit}.txt").touch()


def build(project, feed, branch, conflict_version, fetch, gerrit_id=0):
    lib.git.clone(project, fetch)
    lib.git.clean(project)
    if gerrit_id > 0:
        lib.git.checkout_from_review(project, gerrit_id)
    else:
        checkout_for_feed(project, feed, branch)
    version = get_version_for_feed(project, feed, conflict_version)
    epoch = get_epoch(project)
    version_epoch = f"{epoch}:{version}" if epoch else version
    has_rpm_spec = lib.rpm_spec.get_spec_in_path(project) is not None

    print(f"{project}: building source package {version_epoch}")
    write_tarball_version(project, version_epoch)

    if project in lib.config.projects_osmocom:
        metapkg = f"osmocom-{feed}"
        lib.debian.control_add_depend(project, metapkg, conflict_version)
        if has_rpm_spec:
            lib.rpm_spec.add_depend(project, metapkg, conflict_version)

    lib.debian.changelog_add_entry_if_needed(project, feed, version_epoch)

    os.makedirs(lib.get_output_path(project))
    lib.remove_cache_extra_files()

    project_specific_func = f"prepare_project_{os.path.basename(project)}"
    if project_specific_func in globals():
        print(f"{project}: running {project_specific_func}")
        globals()[project_specific_func]()

    lib.debian.build_source_package(project)
    lib.debian.move_files_to_output(project)

    if has_rpm_spec:
        lib.rpm_spec.generate(project, version, epoch)
        lib.rpm_spec.copy_to_output(project)

    if feed == "master":
        write_commit_txt(project)

    lib.remove_cache_extra_files()
    return version_epoch
