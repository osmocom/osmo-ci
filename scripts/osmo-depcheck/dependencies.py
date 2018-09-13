# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2018 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>

import collections
import os
import subprocess
import sys

# Same folder
import parse


def git_clone(gitdir, prefix, repository, version):
    """ Clone a missing git repository and checkout a specific version tag.

        :param gitdir: folder to which the sources will be cloned
        :param prefix: git url prefix (e.g. "git://git.osmocom.org/")
        :param repository: Osmocom git repository name (e.g. "libosmo-abis")
        :param version: "master" or a version tag like "0.11.0" """
    # Clone when needed
    if not os.path.exists(gitdir + "/" + repository):
        url = prefix + repository
        print("Cloning git repo: " + url)
        try:
            subprocess.run(["git", "-C", gitdir, "clone", "-q", url],
                           check=True)
        except subprocess.CalledProcessError:
            print("NOTE: if '" + repository + "' is part of a git repository"
                  " with a different name, please add it to the mapping in"
                  " 'config.py' and try again.")
            sys.exit(1)

    # Checkout the version tag
    subprocess.run(["git", "-C", gitdir + "/" + repository, "checkout",
                    version, "-q"], check=True)


def generate(gitdir, prefix, initial, rev):
    """ Generate the dependency graph of an Osmocom program by cloning the git
        repository, parsing the "configure.ac" file, and recursing.

        :param gitdir: folder to which the sources will be cloned
        :param prefix: git url prefix (e.g. "git://git.osmocom.org/")
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
        git_clone(gitdir, prefix, program, version)
        depends = parse.configure_ac(gitdir, program)
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


def git_latest_tag(gitdir, repository):
    """ Get the last release string by asking git for the latest tag.

        :param gitdir: folder to which the sources will be cloned
        :param repository: Osmocom git repository name (e.g. "libosmo-abis")
        :returns: the latest git tag (e.g. "1.0.2") """
    dir = gitdir + "/" + repository
    complete = subprocess.run(["git", "-C", dir, "describe", "--abbrev=0",
                               "master"], check=True, stdout=subprocess.PIPE)
    return complete.stdout.decode().rstrip()


def print_old(gitdir, depends):
    """ Print dependencies tied to an old release tag

        :param gitdir: folder to which the sources will be cloned
        :param depends: return value from generate() above """
    print("Dependencies on old releases:")

    for program, data in depends.items():
        for depend, version in data["depends"].items():
            latest = git_latest_tag(gitdir, depend)
            if latest == version:
                continue
            print(" * " + program + ":" + data["version"] + " -> " +
                  depend + ":" + version + " (latest: " + latest + ")")
