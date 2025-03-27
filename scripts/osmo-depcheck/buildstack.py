# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2018 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>

import collections
import sys
import os
import subprocess


def next_buildable(depends, done):
    """ Find the next program that can be built, because it has all
        dependencies satisfied. Initially this would be libosmocore, as it has
        no dependencies, then the only library that depends on libosmocore and
        so on.

        :param depends: return value of dependencies.generate()
        :param done: ordered dict of programs that would already have been
                     built at this point.
                     Example: {"lib-a": "0.11.0", "lib-b": "0.5.0"}
    """
    # Iterate over dependencies
    for program, data in depends.items():
        # Skip what's already done
        if program in done:
            continue

        # Check for missing dependencies
        depends_done = True
        for depend in data["depends"]:
            if depend not in done:
                depends_done = False
                break

        # All dependencies satisfied: we have a winner!
        if depends_done:
            return program, data["version"]

    # Impossible to build the dependency tree
    print_dict(done)
    print("ERROR: can't figure out how to build the rest!")
    sys.exit(1)


def generate(depends):
    """ Generate an ordered dictionary with the right build order.

        :param depends: return value of dependencies.generate()
        :returns: an ordered dict like the following:
                  {"libosmocore": "0.11.0",
                   "libosmo-abis": "0.5.0",
                   "osmo-bts": "master"} """
    # Iterate over dependencies
    ret = collections.OrderedDict()
    count = len(depends.keys())
    while len(ret) != count:
        # Continue with the one without unsatisfied dependencies
        program, version = next_buildable(depends, ret)
        ret[program] = version
    return ret


def print_dict(stack):
    """ Print the whole build stack.
        :param stack: return value from generate() above """
    print("Build order:")
    for program, version in stack.items():
        print(" * " + program + ":" + version)


def set_environment(jobs, prefix):
    """ Configure the environment variables before running configure, make etc.

        :param jobs: parallel build jobs (for make)
        :param prefix: installation folder
    """
    # Add prefix to PKG_CONFIG_PATH and LD_LIBRARY_PATH
    extend = {"PKG_CONFIG_PATH": prefix + "/lib/pkgconfig",
              "LD_LIBRARY_PATH": prefix + "/lib"}
    for env_var, folder in extend.items():
        old = os.environ[env_var] if env_var in os.environ else ""
        os.environ[env_var] = old + ":" + folder

    # Set JOBS for make
    os.environ["JOBS"] = str(jobs)


def build(workdir, jobs, stack):
    """ Build one program with all its dependencies.

        :param workdir: path to where all data (git, build, install) is stored
        :param jobs: parallel build jobs (for make)
        :param stack: the build stack as returned by generate() above

        The dependencies.clone() function has already downloaded missing
        sources and checked out the right version tags. So in this function we
        can directly enter the source folder and run the build commands.

        Notes about the usage of 'make clean' and 'make distclean':
        * Without 'make clean' we might have files in the build directory with
          a different prefix hardcoded (e.g. from a previous run of
          osmo-depcheck):
          <https://lists.gnu.org/archive/html/libtool/2006-12/msg00011.html>
        * 'make distclean' gets used to remove everything that mentioned the
          prefix set by osmo-depcheck. That way the user won't have it set
          anymore in case they decide to compile the code again manually from
          the source folder. """
    # Prepare the install folder and environment
    prefix = workdir + "/install"
    unitdir = prefix + "/lib/systemd/system/"
    set_environment(jobs, prefix)

    # Iterate over stack
    for program, version in stack.items():
        print("Building " + program + ":" + version)

        # Create and enter the build folder
        builddir = workdir + "/build/" + program
        os.mkdir(builddir)
        os.chdir(builddir)

        # Run the build commands
        gitdir = workdir + "/git/" + program
        commands = [["autoreconf", "-fi", gitdir],
                    [gitdir + "/configure", "--prefix", prefix,
                     "--with-systemdsystemunitdir=" + unitdir],
                    ["make", "clean"],
                    ["make"],
                    ["make", "install"],
                    ["make", "distclean"]]
        for command in commands:
            print("+ " + " ".join(command))
            subprocess.run(command, check=True)
