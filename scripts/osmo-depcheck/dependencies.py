# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2018 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>

import collections
import os
import subprocess
import sys

# Same folder
import parse


def git_clone(workdir, prefix, cache_git_fetch, repository, version):
    """ Clone a missing git repository and checkout a specific version tag.

        :param workdir: path to where all data (git, build, install) is stored
        :param prefix: git url prefix (e.g. "git://git.osmocom.org/")
        :param cache_git_fetch: list of repositories that have already been
                                fetched in this run of osmo-depcheck
        :param repository: Osmocom git repository name (e.g. "libosmo-abis")
        :param version: "master" or a version tag like "0.11.0" """
    repodir = workdir + "/git/" + repository
    if repository not in cache_git_fetch:
        if os.path.exists(repodir):
            # Fetch tags for existing source
            print("Fetching tags...")
            subprocess.run(["git", "-C", repodir, "fetch", "--tags", "-q"],
                           check=True)
        else:
            # Clone the source
            url = prefix + repository
            print("Cloning git repo: " + url)
            try:
                subprocess.run(["git", "-C", workdir + "/git", "clone", "-q",
                                url], check=True)
            except subprocess.CalledProcessError:
                print("NOTE: if '" + repository + "' is part of a git"
                      " repository with a different name, please add it to the"
                      " mapping in 'config.py' and try again.")
                sys.exit(1)

        # Only fetch the same repository once per session
        cache_git_fetch.append(repository)

    # Checkout the version tag
    try:
        subprocess.run(["git", "-C", repodir, "checkout", version, "-q"],
                       check=True)
    except subprocess.CalledProcessError:
        print("ERROR: git checkout failed! Invalid version specified?")
        sys.exit(1)


def generate(workdir, prefix, cache_git_fetch, initial, rev):
    """ Generate the dependency graph of an Osmocom program by cloning the git
        repository, parsing the "configure.ac" file, and recursing.

        :param workdir: path to where all data (git, build, install) is stored
        :param prefix: git url prefix (e.g. "git://git.osmocom.org/")
        :param cache_git_fetch: list of repositories that have already been
                                fetched in this run of osmo-depcheck
        :param initial: the first program to look at (e.g. "osmo-bts")
        :param rev: the git revision to check out ("master", "0.1.0", ...)
        :returns: a dictionary like the following:
                  {"osmo-bts": {"version": "master",
                                "depends": {"libosmocore": "0.11.0",
                                            "libosmo-abis": "0.5.0"}},
                   "libosmocore": {"version": "0.11.0",
                                   "depends": {}},
                   "libosmo-abis": {"version": "0.5.0",
                                    "depends": {"libosmocore": "0.11.0"}} """
    # Iterate over stack
    stack = collections.OrderedDict({initial: rev})
    ret = collections.OrderedDict()
    while len(stack):
        # Pop program from stack
        program, version = next(iter(stack.items()))
        del stack[program]

        # Skip when already parsed
        if program in ret:
            continue

        # Add the programs dependencies to the stack
        print("Looking at " + program + ":" + version)
        git_clone(workdir, prefix, cache_git_fetch, program, version)
        depends = parse.configure_ac(workdir, program)
        stack.update(depends)

        # Add the program to the ret
        ret[program] = {"version": version, "depends": depends}

    return ret


def print_dict(depends):
    """ Print the whole dependency graph.
        :param depends: return value from generate() above """
    print("Dependency graph:")

    for program, data in depends.items():
        version = data["version"]
        depends = data["depends"]
        print(" * " + program + ":" + version + " depends: " + str(depends))


def git_latest_tag(workdir, repository):
    """ Get the last release string by asking git for the latest tag.

        :param workdir: path to where all data (git, build, install) is stored
        :param repository: Osmocom git repository name (e.g. "libosmo-abis")
        :returns: the latest git tag (e.g. "1.0.2") """
    dir = workdir + "/git/" + repository
    complete = subprocess.run(["git", "-C", dir, "describe", "--abbrev=0",
                               "master"], check=True, stdout=subprocess.PIPE)
    return complete.stdout.decode().rstrip()


def print_old(workdir, depends):
    """ Print dependencies tied to an old release tag

        :param workdir: path to where all data (git, build, install) is stored
        :param depends: return value from generate() above """
    print("Dependencies on old releases:")

    for program, data in depends.items():
        for depend, version in data["depends"].items():
            latest = git_latest_tag(workdir, depend)
            if latest == version:
                continue
            print(" * " + program + ":" + data["version"] + " -> " +
                  depend + ":" + version + " (latest: " + latest + ")")
