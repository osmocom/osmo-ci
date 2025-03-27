#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2023 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import argparse
import hashlib
import html
import os
import shlex
import shutil
import sys
import xml.etree.ElementTree

import lib
import lib.docker
import lib.osc

temp_source_prjconf = f"{lib.config.path_temp}/sync_source_prjconf"
temp_source_meta = f"{lib.config.path_temp}/sync_source_meta"
temp_dest_old_meta = f"{lib.config.path_temp}/sync_dest_old_meta"
temp_dest_old_prjconf = f"{lib.config.path_temp}/sync_dest_old_prjconf"
temp_dest_new_meta = f"{lib.config.path_temp}/sync_dest_new_meta"
temp_dest_new_prjconf = f"{lib.config.path_temp}/sync_dest_new_prjconf"


def parse_args():
    parser = argparse.ArgumentParser(description="Sync OBS projects (prjconf,"
        " meta) from another instance (OS#6165)")
    parser.add_argument("-d", "--docker",
                        help="run in docker to avoid installing required pkgs",
                        action="store_true")
    parser.add_argument("-n", "--no-skip-up-to-date",
                        dest="skip_up_to_date", action="store_false",
                        help="always assume projects are outdated")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="always print shell commands and their output,"
                             " instead of only printing them on error")
    parser.add_argument("projects",
                        help="source OBS project, e.g. Debian:12",
                        nargs="+")

    advanced = parser.add_argument_group("advanced options")
    advanced.add_argument("-A", "--apiurl", help="source OBS API URL"
                          " (default: https://api.opensuse.org)",
                          default="https://api.opensuse.org")
    advanced.add_argument("-p", "--prefix", default="openSUSE.org-mirror",
                          help="destination OBS prefix"
                               " (default: openSUSE.org-mirror)")
    advanced.add_argument("-t", "--to-apiurl", help="destination OBS API URL"
                          " (default: https://obs.osmocom.org)",
                          default="https://obs.osmocom.org")
    advanced.add_argument("-w", "--weburl", default="https://build.opensuse.org",
                          help="source OBS web URL (default:"
                               " https://build.opensuse.org)")

    args = parser.parse_args()
    lib.set_args(args)

    lib.osc.check_oscrc()

    if args.docker:
        lib.docker.run_in_docker_and_exit("sync_obs_projects.py", add_oscrc=True)


def check_required_programs():
    required_programs = [
        "colordiff",
        "xmllint",
    ]

    ok = True
    for program in required_programs:
        if not shutil.which(program):
            print(f"ERROR: missing program: {program}")
            ok = False

    if not ok:
        print("Either install them or use the -d argument to run in docker")
        sys.exit(1)


def generate_prjconf_header(project):
    """ This header gets prepended to the prjconf, before it gets written to
        the destination OBS. This script uses it to determine whether the
        project needs to be updated next time it runs. """
    with open(temp_source_prjconf, "rb") as h:
        source_prjconf = h.read()
    with open(temp_source_meta, "rb") as h:
        source_meta = h.read()

    ret = "### This project gets synced from:\n"
    ret += f"### {lib.args.weburl}/project/show/{project}\n"
    ret += "### \n"
    ret += "### Do not modify manually. See OS#6165.\n"
    ret += "### \n"
    ret += "### Sync information:\n"
    ret += f"### - source meta: {hashlib.md5(source_meta).hexdigest()}\n"
    ret += f"### - source prjconf: {hashlib.md5(source_prjconf).hexdigest()}\n"
    ret += "\n"

    return ret


def is_up_to_date(header, projects, project):
    project_new = f"{lib.args.prefix}:{project}"

    if project_new not in projects:
        print(f"{project_new}: is outdated (not in destination OBS)")
        return False

    lib.osc.get_prjconf(temp_dest_old_prjconf)
    with open(temp_dest_old_prjconf, "r") as h:
        dest_prjconf = h.read()

    if dest_prjconf.startswith(header):
        if not lib.args.skip_up_to_date:
            print(f"{project_new}: is up-to-date, but -n is set")
            return False
        print(f"{project_new}: is up-to-date")
        return True

    print(f"{project_new}: is outdated")
    return False


def get_relevant_arches(project):
    if project.startswith("AlmaLinux:"):
        return ["x86_64"]
    if project.startswith("Raspbian:"):
        return ["armv7l"]

    return ["aarch64",
            "armv7l",
            "i586",
            "x86_64"]


def rewrite_meta(project):
    project_new = f"{lib.args.prefix}:{project}"
    print(f"{project}: rewriting meta for {project_new}")
    tree = xml.etree.ElementTree.parse(temp_source_meta)
    root = tree.getroot()
    arches = get_relevant_arches(project)

    # Update <project name="...">
    assert root.get("name") == project
    root.set("name", project_new)

    for description in root.findall("description"):
        href = f"{lib.args.weburl}/project/show/{project}"
        description.text = ("This project gets synced from:"
                            f" <a href='{html.escape(href)}'>{project}</a>\n"
                            "Do not modify manually. See OS#6165.\n")

    for repository in root.findall(".repository"):
        repo_name = repository.get("name")
        print(f"  adjusting repository: {repo_name}")
        for path in repository.findall(".path"):
            # Update <path project="...">
            path_project_old = path.get("project")
            path_project_new = f"{lib.args.prefix}:{path_project_old}"
            path.set("project", path_project_new)

            # Remove unneeded paths
            for path_check in lib.config.sync_remove_paths:
                if path_project_old == path_check:
                    print(f"    removing path: {path_project_old}")
                    repository.remove(path)
                    break

        # Remove arches we don't build for
        for arch in repository.findall(".arch"):
            if arch.text not in arches:
                print(f"    removing arch: {arch.text}")
                repository.remove(arch)
        for download in repository.findall(".download"):
            if download.get("arch") not in arches:
                repository.remove(download)

        # Debian: meta configs on build.opensuse.org reference PGP keys with an
        # experimental feature that is not yet in the stable version of OBS
        # (e.g. <pubkey>debian-archive-12</pubkey>):
        # https://github.com/openSUSE/open-build-service/pull/14528
        # Also we don't have such a pubkeydir set up on our OBS server. Assume
        # https://debian.inf.tu-dresden.de/ is a trusted mirror, switch to
        # HTTPS and skip the PGP verification by removing the pubkey blocks.
        if project.startswith("Debian:"):
            for download in repository.findall(".download"):
                url = download.get("url")
                print(f"    changing url to https: {url}")
                assert url.startswith("http://ftp.de.debian.org/debian"), \
                        "unexpected mirror URL"
                download.set("url", url.replace("http://ftp.de.debian.org/debian",
                                                "https://debian.inf.tu-dresden.de/debian"))
                for pubkey in download.findall("pubkey"):
                    download.remove(pubkey)

    # Remove original maintainers
    for person in root.findall(".person"):
        root.remove(person)

    # Add new maintainers
    for userid in lib.config.sync_set_maintainers:
        print(f"  set maintainer: {userid}")
        person = xml.etree.ElementTree.Element("person")
        person.set("userid", userid)
        person.set("role", "maintainer")
        # Insert into same position: after title and description
        root.insert(2, person)

    tree.write(temp_dest_new_meta)


def rewrite_prjconf(project, header):
    project_new = f"{lib.args.prefix}:{project}"
    print(f"{project}: rewriting prjconf for {project_new}")

    prjconf = ""
    with open(temp_source_prjconf, "r") as f:
        for line in f:
            line = line.rstrip()

            # Remove unneeded dependencies
            if line == "VMInstall: kernel-obs-build":
                print(f"  commenting out: {line}")
                line = f"# (commented out by sync) {line}"

            prjconf += f"{line}\n"

        # Extend the AlmaLinux prjconf to also set CentOS variables, as some of
        # our prjconfigs and spec files rely on them
        if project == "AlmaLinux:8":
            print("  appending CentOS 8 variables")
            prjconf += "\n"
            prjconf += "# CentOS 8 compat added by sync script\n"
            prjconf += "%define centos_version 800\n"
            prjconf += "%define centos_ver 8\n"
            prjconf += "%define centos 8\n"
            prjconf += "Macros:\n"
            prjconf += "%centos_version 800\n"
            prjconf += "%centos_ver 8\n"
            prjconf += "%centos 8\n"
            prjconf += ":Macros\n"

    with open(temp_dest_new_prjconf, "w") as f:
        f.write(header)
        f.write(prjconf)


def show_diff(projects, project):
    project_new = f"{lib.args.prefix}:{project}"
    if project_new not in projects:
        return

    # Show prjconf diff (old prjconf was retrieved in is_up_to_date())
    diff = lib.run_cmd(["colordiff",
                        "-c3",
                        temp_dest_old_prjconf,
                        temp_dest_new_prjconf],
                       check=False)
    if diff.returncode:
        print(f"{project_new}: prjconf changes:")
        print(diff.output, end="")
    else:
        print(f"{project_new}: prjconf is unchanged")

    # Show meta diff
    lib.osc.get_meta(temp_dest_old_meta)
    for file in [temp_dest_old_meta, temp_dest_new_meta]:
        lib.run_cmd(f"xmllint --format {shlex.quote(file)} > {shlex.quote(file)}.pretty",
                    shell=True)
    diff = lib.run_cmd(["colordiff",
                        "-c3",
                        f"{temp_dest_old_meta}.pretty",
                        f"{temp_dest_new_meta}.pretty"],
                       check=False)
    if diff.returncode:
        print(f"{project_new}: meta changes:")
        print(diff.output, end="")
    else:
        print(f"{project_new}: meta is unchanged")


def main():
    parse_args()
    check_required_programs()

    os.makedirs(lib.config.path_temp, exist_ok=True)

    # Get destination OBS projects
    lib.osc.set_apiurl(lib.args.to_apiurl, None)
    dest_projects = lib.osc.get_projects()

    for project in lib.args.projects:
        # Talk to source OBS
        lib.osc.set_apiurl(lib.args.apiurl, project)

        # Get source prjconf, meta
        lib.osc.get_prjconf(temp_source_prjconf)
        lib.osc.get_meta(temp_source_meta)

        # Talk to dest OBS
        project_new = f"{lib.args.prefix}:{project}"
        lib.osc.set_apiurl(lib.args.to_apiurl, project_new)

        # Check if dest is up-to-date
        header = generate_prjconf_header(project)
        if is_up_to_date(header, dest_projects, project):
            continue

        # Rewrite configs and show diff
        rewrite_prjconf(project, header)
        rewrite_meta(project)
        show_diff(dest_projects, project)

        # Update dest prjconf & meta
        commit_msg = f"sync with {lib.args.weburl}/project/show/{project}"
        lib.osc.update_meta(temp_dest_new_meta, commit_msg)
        lib.osc.update_prjconf(temp_dest_new_prjconf, commit_msg)


if __name__ == "__main__":
    main()
