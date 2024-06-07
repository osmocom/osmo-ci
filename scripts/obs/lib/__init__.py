#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import inspect
import lib.config

# Argparse result
args = None

# Print output of commands as they run, not only on error
cmds_verbose = False


def add_shared_arguments(parser):
    """ Arguments shared between build_srcpkg.py and update_obs_project.py. """

    group_reqprog = parser.add_argument_group("required program options")
    group_reqprog.add_argument("-d", "--docker", help="run in docker to avoid"
                               " installing required pkgs",
                               action="store_true")
    group_reqprog.add_argument("-i", "--ignore-req", action="store_true",
                               help="skip required programs check")

    group_feed = parser.add_argument_group("feed options",
        "The feed option implies the source revision (nightly/master: build"
        " the master branch; latest: build the last tag) and when a package"
        " is considered outdated (latest/master: when the commit changes on"
        " the latest tag or on master; nightly: always).")
    group_feed.add_argument("-f", "--feed", help="package feed (default:"
                            " nightly, can also be master or latest)",
                            metavar="FEED", default="nightly",
                            choices=lib.config.feeds)

    group_pkg = parser.add_argument_group("package options")
    group_pkg.add_argument("-a", "--allow-unknown-package",
                           action="store_true",
                           help="don't complain if the name of the package is"
                                " not stored in lib/config.py")
    group_pkg.add_argument("-e", "--version-append",
                           help="add a string at the end of the version, e.g."
                                " '~osmocom' for the wireshark package")

    group_git = parser.add_argument_group("git options")
    group_git.add_argument("-b", "--git-branch", help="instead of using a"
                           " branch based on the feed, checkout this git"
                           " branch", metavar="BRANCH", default=None)
    group_git.add_argument("-s", "--git-skip-fetch",
                           help="do not fetch already cloned git repositories",
                           action="store_false", dest="git_fetch")
    group_git.add_argument("-S", "--git-skip-checkout",
                           help="do not checkout and reset to a branch/tag",
                           action="store_false", dest="git_checkout")

    group_meta = parser.add_argument_group("meta package options",
        "Osmocom packages depend on a meta-package such as osmocom-nightly."
        " These meta-packages conflict with each other to ensure e.g."
        " incompatible nightly and latest packages are not mixed by accident."
        " For nightly we don't have API compatibility and so we let these"
        " depend on a meta package of a specific build date (-c).")
    group_meta.add_argument("-m", "--meta", action="store_true",
                            help="build a meta package (e.g. osmocom-nightly)")
    group_meta.add_argument("-c", "--conflict-version", nargs="?",
                            help="depend on meta-package of specific version")
    group_meta.add_argument("-p", "--conflict-pkgname", nargs="?",
                            help="name of the meta-package to depend on"
                                " (default: osmocom-$feed)")
    group_meta.add_argument("-M", "--no-meta", action="store_true",
                            help="Don't depend on the meta package (use when"
                                 " building one-off packages for development)")

    group_devel = parser.add_argument_group("development options")
    group_devel.add_argument("-v", "--verbose", action="store_true",
                        help="always print shell commands and their output,"
                             " instead of only printing them on error")

    return {
        "devel": group_devel,
        "feed": group_feed,
        "git": group_git,
        "meta": group_meta,
        "pkg": group_pkg,
        "reqprog": group_reqprog,
    }


def set_cmds_verbose(new_val):
    global cmds_verbose
    cmds_verbose = new_val


def set_args(new_val):
    global args
    args = new_val
    set_cmds_verbose(args.verbose)


def check_required_programs():
    ok = True

    for program in lib.config.required_programs:
        if not shutil.which(program):
            print(f"ERROR: missing program: {program}")
            ok = False

    for module in lib.config.required_python_modules:
        if not importlib.util.find_spec(module):
            print(f"ERROR: missing python3 module: {module}")
            ok = False

    if not ok:
        print("Either install them or use the -d argument to run in docker")
        sys.exit(1)


def set_proper_package_name(package):
    if package in lib.config.projects_osmocom:
        return package
    if package in lib.config.projects_other:
        return package

    # Add prefix to Osmocom package if missing
    for package_cfg in lib.config.projects_osmocom:
        if os.path.basename(package_cfg) == package:
            return package_cfg

    if lib.args.allow_unknown_package:
        return package

    print(f"ERROR: unknown package: {package}")
    print("See projects_osmocom and projects_other in obs/lib/config.py")
    sys.exit(1)


def exit_error_cmd(completed, error_msg):
    """ :param completed: return from run_cmd() below """
    global cmds_verbose

    print()
    print(f"ERROR: {error_msg}")
    print()
    print(f"*** command ***\n{completed.args}\n")
    print(f"*** returncode ***\n{completed.returncode}\n")

    if not cmds_verbose:
        print(f"*** output ***\n{completed.output}")

    print("*** python trace ***")
    raise RuntimeError("shell command related error, find details right above"
                       " this python trace")


def run_cmd(cmd, check=True, *args, **kwargs):
    """ Like subprocess.run, but has check=True and text=True by default and
        allows capturing the output while displaying it at the same time. By
        default the output is hidden unless there's an error, with -v the
        output gets written to stdout.
        :returns: subprocess.CompletedProcess instance, but with combined
                  stdout + stderr written to ret.output
        :param check: stop with error if exit code is not 0 """
    global cmds_verbose

    caller = inspect.stack()[2][3]
    if cmds_verbose:
        print(f"+ {caller}(): {cmd}")

    with tempfile.TemporaryFile(encoding="utf8", mode="w+") as output_buf:
        p = subprocess.Popen(cmd, stdin=subprocess.DEVNULL,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, bufsize=1, *args, **kwargs)

        while True:
            out = p.stdout.read(1)
            if out == "" and p.poll() is not None:
                break
            if out != "":
                output_buf.write(out)
                if cmds_verbose:
                    sys.stdout.write(out)
                    sys.stdout.flush()

        output_buf.seek(0)
        setattr(p, "output", output_buf.read())

    if p.returncode == 0 or not check:
        return p

    exit_error_cmd(p, "command failed unexpectedly")


def remove_temp():
    run_cmd(["rm", "-rf", lib.config.path_temp])


def remove_cache_extra_files():
    """ dpkg-buildpackage outputs all files to the top dir of the package
        dir, so it will always put them in _cache when building e.g. the debian
        source package of _cache/libosmocore. Clear all extra files from _cache
        that don't belog to the git repositories which we actually want to
        cache. """
    run_cmd(["find", lib.config.path_cache, "-maxdepth", "1", "-type", "f",
             "-delete"])


def get_output_path(project):
    return f"{lib.config.path_temp}/srcpkgs/{os.path.basename(project)}"
