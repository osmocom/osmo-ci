#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import importlib
import os
import shutil
import subprocess
import sys
import tempfile
import inspect
import lib.config

cmds_verbose = False


def add_shared_arguments(parser):
    """ Arguments shared between build_srcpkg.py and update_obs_project.py. """
    parser.add_argument("-f", "--feed",
			help="package feed (default: nightly). The feed"
			" determines the git revision to be built:"
			" 'nightly' and 'master' build 'origin/master',"
			" 'latest' builds the last signed tag,"
			" other feeds build their respective branch.",
                        metavar="FEED", default="nightly",
                        choices=lib.config.feeds)
    parser.add_argument("-b", "--git-branch", help="instead of using a branch"
                              " based on the feed, checkout this git branch",
                        metavar="BRANCH", default=None)
    parser.add_argument("-d", "--docker",
                        help="run in docker to avoid installing required pkgs",
                        action="store_true")
    parser.add_argument("-s", "--git-skip-fetch",
                        help="do not fetch already cloned git repositories",
                        action="store_false", dest="git_fetch")
    parser.add_argument("-m", "--meta", action="store_true",
                        help="build a meta package (e.g. osmocom-nightly)")
    parser.add_argument("-i", "--ignore-req", action="store_true",
                        help="skip required programs check")
    parser.add_argument("-c", "--conflict-version", nargs="?",
                        help="Of the generated source packages, all Osmocom"
                             " packages (not e.g. open5gs, see lib/config.py"
                             " for full list) depend on a meta-package such as"
                             " osmocom-nightly, osmocom-latest, osmocom-2021q1"
                             " etc. These meta-packages conflict with each"
                             " other to ensure that one does not mix e.g."
                             " latest and nightly packages by accident."
                             " With this -c argument, it is possible to let"
                             " these packages depend on a meta-package of a"
                             " specific version. This is used for nightly and"
                             " 20YYqX packages to ensure they are not mixed"
                             " from different build dates (ABI compatibility"
                             " is only on latest).")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="always print shell commands and their output,"
                             " instead of only printing them on error")


def set_cmds_verbose(new_val):
    global cmds_verbose
    cmds_verbose = new_val


def check_required_programs():
    ok = True

    for program in lib.config.required_programs:
        if not shutil.which(program):
            print(f"ERROR: missing program: {program}")
            ok = False

    for module in lib.config.required_python_modules:
        if not importlib.find_loader(module):
            print(f"ERROR: missing python3 module: {module}")
            ok = False

    if not ok:
        print("Either install them or use the -d argument to run in docker")
        exit(1)


def check_package(package):
    if package in lib.config.projects_osmocom:
        return
    if package in lib.config.projects_other:
        return

    print(f"ERROR: unknown package: {package}")
    print("See packages_osmocom and packages_other in obs/lib/config.py")
    exit(1)


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
