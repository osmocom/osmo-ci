#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import glob
import os
import pathlib
import lib.config
import lib.debian
import lib.rpm_spec


def checkout_for_feed(project):
    """checkout a commit, either latest tag or master or 20YY branch"""
    feed = lib.args.feed
    branch = lib.args.git_branch
    if branch:
        lib.git.checkout(project, f"origin/{branch}")
    elif feed == "latest":
        lib.git.checkout_latest_tag(project)
    elif feed in ["master", "nightly"]:
        lib.git.checkout_default_branch(project)
    else:  # 2022q1 etc
        lib.git.checkout(project, f"origin/{feed}")


def get_git_version(project):
    """:returns: the string from git-version-gen, e.g. '1.7.0.10-76bdb'"""
    repo_path = lib.git.get_repo_path(project)

    # Run git-version-gen if it is in the repository
    script_path = f"{repo_path}/git-version-gen"
    if os.path.exists(script_path):
        ret = lib.run_cmd([script_path, "."], cwd=repo_path).output.rstrip()
        if not ret:
            lib.exit_error_cmd(ret, "empty output from git-version-gen")
        return ret

    # Generate a version string similar to git-version-gen, but run use git
    # describe --tags, so it works with non-annotated tags as well (needed for
    # e.g. limesuite's tags).
    pattern = lib.git.get_latest_tag_pattern(project)
    pattern = pattern.replace("^", "", 1)
    pattern = pattern.replace("$", "", -1)
    result = lib.run_cmd(
        [
            "git",
            "describe",
            "--abbrev=4",
            "--tags",
            f"--match={pattern}",
            "HEAD",
        ],
        cwd=repo_path,
        check=False,
    )

    if result.returncode == 128:
        print(f"{project}: has no git tags")
        commit = lib.run_cmd(
            ["git", "rev-parse", "HEAD"],
            cwd=repo_path,
        ).output[0:4]
        count = lib.run_cmd(
            ["git", "rev-list", "--count", "HEAD"],
            cwd=repo_path,
        ).output.rstrip()
        try:
            print(f"{project}: getting version from debian/changelog")
            version = lib.debian.get_last_version_from_changelog(project)
            return f"{version}.{count}-{commit}"
        except:  # noqa: E722
            print(f"{project}: using 0.0.0 as version")
            return f"0.0.0.{count}-{commit}"

    if result.returncode != 0:
        lib.exit_error_cmd(result, "command failed unexpectedly")

    ret = result.output.rstrip()

    # Like git-version-gen:
    # * Change the first '-' to '.'
    # * Remove the 'g' in git describe's output string
    # * Remove the leading 'v'
    ret = ret.replace("-", ".", 1)
    ret = ret.replace("-g", "-", 1)
    if ret.startswith("v"):
        ret = ret[1:]

    return ret


def get_version_for_feed(project):
    if lib.args.feed == "latest":
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
    conflict_version = lib.args.conflict_version
    if conflict_version:
        ret = f"{ret}.{conflict_version}"

    return ret


def get_epoch(project):
    """The osmo-gbproxy used to have the same package version as osmo-sgsn
    until 2021 where it was split into its own git repository. From then on,
    osmo-gbproxy has a 0.*.* package version, which is smaller than the
    previous 1.*.* from osmo-sgsn. We had to set the epoch to 1 for
    osmo-gbproxy so package managers know these 0.*.* versions are higher than
    the previous 1.*.* ones that are still found in e.g. debian 11. The epoch
    is set in debian/changelog, retrieve it from there.
    :returns: the epoch number if set, e.g. "1" or an empty string"""
    version_epoch = lib.debian.get_last_version_from_changelog(project)

    if ":" in version_epoch:
        return version_epoch.split(":")[0]

    return ""


def prepare_project_open5gs():
    """Download the subproject sources here, so the package can be built in
    OBS without Internet access."""
    lib.run_cmd(
        ["meson", "subprojects", "download"],
        cwd=lib.git.get_repo_path("open5gs"),
    )


def run_generate_build_dep(project):
    """Run contrib/generate_build_dep.sh if it exists in the given project, to
    to download sources for dependencies (see e.g. osmo_dia2gsup.git)."""
    repo_path = lib.git.get_repo_path(project)
    script_path = "contrib/generate_build_dep.sh"

    if os.path.exists(f"{repo_path}/{script_path}"):
        print(f"{project}: running {script_path}")
        lib.run_cmd(script_path, cwd=repo_path)


def write_tarball_version(project, version):
    repo_path = lib.git.get_repo_path(project)

    with open(f"{repo_path}/.tarball-version", "w") as f:
        f.write(f"{version}\n")


def write_commit_txt(project):
    """Write the current git commit to commit_$commit.txt file, so it gets
    uploaded to OBS along with the rest of the source package. This allows
    figuring out if the source package is still up-to-date or not for the
    master feed."""
    output_path = lib.get_output_path(project)
    commit = lib.git.get_head(project)

    print(f"{project}: adding commit_{commit}.txt")
    pathlib.Path(f"{output_path}/commit_{commit}.txt").touch()


def set_asciidoc_style_without_draft_watermark(project):
    repo_path = lib.git.get_repo_path(project)
    doc_makefiles = lib.run_cmd(
        ["grep", "-r", "-l", "include $(OSMO_GSM_MANUALS_DIR)/build/Makefile.asciidoc.inc"],
        cwd=repo_path,
        check=False,
    )
    doc_makefiles = doc_makefiles.output.rstrip().split("\n")

    for doc_makefile in doc_makefiles:
        if doc_makefile == "":
            continue
        print(f"{project}: setting asciidoc style to remove draft watermark in {doc_makefile}")
        lib.run_cmd(
            [
                "sed",
                "-i",
                "/\\/build\\/Makefile\\.asciidoc\\.inc/s/^/  ASCIIDOCSTYLE = $(BUILDDIR)\\/custom-dblatex.sty\\n/",
                doc_makefile,
            ],
            cwd=repo_path,
        )


def build(project, gerrit_id=0):
    conflict_version = lib.args.conflict_version
    feed = lib.args.feed
    version_append = lib.args.version_append

    lib.git.clone(project)
    lib.git.clean(project)
    if gerrit_id > 0:
        lib.git.checkout_from_review(project, gerrit_id)
    else:
        checkout_for_feed(project)

    version = get_version_for_feed(project)
    if version_append:
        version += version_append
    epoch = get_epoch(project)
    version_epoch = f"{epoch}:{version}" if epoch else version

    has_rpm_spec = lib.rpm_spec.get_spec_in_path(project) is not None

    print(f"{project}: building source package {version_epoch}")
    write_tarball_version(project, version_epoch)

    if project in lib.config.projects_osmocom and not lib.args.no_meta and project != "osmocom-keyring":
        metapkg = lib.args.conflict_pkgname or f"osmocom-{feed}"
        lib.debian.control_add_depend(project, metapkg, conflict_version)
        if has_rpm_spec:
            lib.rpm_spec.add_depend(project, metapkg, conflict_version)

    lib.debian.changelog_add_entry_if_needed(project, version_epoch)

    os.makedirs(lib.get_output_path(project))
    lib.remove_cache_extra_files()

    project_specific_func = f"prepare_project_{os.path.basename(project)}"
    if project_specific_func in globals():
        print(f"{project}: running {project_specific_func}")
        globals()[project_specific_func]()

    if project in lib.config.projects_osmocom:
        run_generate_build_dep(project)

    if lib.args.configure_append:
        lib.debian.configure_append(project, lib.args.configure_append)

    if lib.args.disable_manuals:
        lib.debian.disable_manuals(project)
    elif feed == "latest":
        set_asciidoc_style_without_draft_watermark(project)

    lib.debian.build_source_package(project)
    lib.debian.move_files_to_output(project)

    if has_rpm_spec:
        lib.rpm_spec.generate(project, version, epoch)
        lib.rpm_spec.copy_to_output(project)

    if feed == "master":
        write_commit_txt(project)

    lib.remove_cache_extra_files()
    return version_epoch


def requires_osmo_gsm_manuals_dev(project):
    """Check if an already built source package has osmo-gsm-manuals-dev in
    Build-Depends of the .dsc file"""
    path_dsc = glob.glob(f"{lib.get_output_path(project)}/*.dsc")
    assert len(path_dsc) == 1, f"failed to get dsc path for {project}"

    with open(path_dsc[0], "r") as handle:
        for line in handle.readlines():
            if line.startswith("Build-Depends:") and "osmo-gsm-manuals-dev" in line:
                return True

    return False
