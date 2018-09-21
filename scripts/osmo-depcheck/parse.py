# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2018 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>

import sys
import fnmatch

# Same folder
import config


def error(line_i, message):
    """ Print a configure.ac error message with the line number.
        :param line_i: the zero based line counter """
    print("ERROR: configure.ac line " + str(line_i+1) + ": " + message)
    sys.exit(1)


def repository(library, version):
    """ Find the git repository that contains a certain library. Based on the
        information in config.py.

        :param library: the name as referenced in the PKG_CHECK_MODULES
                        statement. For example: "libosmoabis"
        :param version: for example "0.5.0"
        :returns: the repository name, e.g. "libosmo-abis" """
    for repo, libraries in config.repos.items():
        if library in libraries:
            print(" * " + library + ":" + version + " (part of " + repo + ")")
            return repo

    print(" * " + library + ":" + version)
    return library


def library_is_relevant(library):
    """ :returns: True when we would build the library in question from source,
                  False otherwise. """
    for pattern in config.relevant_library_patterns:
        if fnmatch.fnmatch(library, pattern):
            return True
    return False


def parse_condition(line):
    """ Find the PKG_CHECK_MODULES conditions in any line from a configure.ac.

        Example lines:
        PKG_CHECK_MODULES(LIBOSMOCORE, libosmocore  >= 0.10.0)
        PKG_CHECK_MODULES(LIBSYSTEMD, libsystemd)

        :returns: * None when there's no condition in that line
                  * a string like "libosmocore  >= 0.1.0" """
    # Only look at PKG_CHECK_MODULES lines
    if "PKG_CHECK_MODULES" not in line:
        return

    # Extract the condition
    ret = line.split(",")[1].split(")")[0].strip()

    # Only look at Osmocom libraries
    library = ret.split(" ")[0]
    if library_is_relevant(library):
        return ret


def library_version(line_i, condition):
    """ Get the library and version strings from a condition.
        :param line_i: the zero based line counter
        :param condition: a condition like "libosmocore  >= 0.1.0" """
    # Split by space and remove empty list elements
    split = list(filter(None, condition.split(" ")))
    if len(split) != 3:
        error(line_i, "invalid condition format, expected something"
                      " like 'libosmocore >= 0.10.0' but got: '" +
                      condition + "'")
    library, operator, version = split

    # Right operator
    if operator == ">=":
        return (library, version)

    # Wrong operator
    error(line_i, "invalid operator, expected '>=' but got: '" +
                  operator + "'")


def configure_ac(workdir, repo):
    """ Parse the PKG_CHECK_MODULES statements of a configure.ac file.

        :param workdir: path to where all data (git, build, install) is stored
        :param repo: the repository to look at (e.g. "osmo-bts")
        :returns: a dictionary like the following:
                  {"libosmocore": "0.11.0",
                   "libosmo-abis": "0.5.0"} """
    # Read configure.ac
    path = workdir + "/git/" + repo + "/configure.ac"
    with open(path) as handle:
        lines = handle.readlines()

    # Parse the file into ret
    ret = {}
    for i in range(0, len(lines)):
        # Parse the line
        condition = parse_condition(lines[i])
        if not condition:
            continue
        (library, version) = library_version(i, condition)

        # Add to ret (with duplicate check)
        repo_dependency = repository(library, version)
        if repo_dependency in ret and version != ret[repo_dependency]:
            error(i, "found multiple PKG_CHECK_MODULES statements for " +
                     repo_dependency + ".git, and they have different"
                     " versions!")
        ret[repo_dependency] = version
    return ret
