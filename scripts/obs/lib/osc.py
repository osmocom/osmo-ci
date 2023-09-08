#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>

import glob
import os
import shlex
import shutil
import sys
import lib
import lib.config

apiurl = None
proj = None


def check_oscrc():
    configdir = os.environ.get("XDG_CONFIG_HOME", "~/.config")
    paths = ["~/.oscrc", f"{configdir}/osc/oscrc"]
    for path in paths:
        if os.path.exists(os.path.expanduser(path)):
            return

    print("ERROR: oscrc does not exist, please create one as explained in the"
          " README.")
    sys.exit(1)


def set_apiurl(url, obs_proj=None):
    global apiurl
    global proj

    if obs_proj is not None:
        if ":" not in obs_proj:
            print(f"ERROR: this doesn't look like a valid OBS project: {obs_proj}")
            sys.exit(1)
        proj = obs_proj

    apiurl = url


def run_osc(cmd, *args, **kwargs):
    global apiurl

    # For some osc commands like 'osc add *' it makes sense to use a flat
    # string and shell=True, hence support both list and string in this wrapper
    if isinstance(cmd, str):
        if apiurl:
            cmd = f"osc -A {shlex.quote(apiurl)} {cmd}"
        else:
            cmd = f"osc {cmd}"
    else:
        if apiurl:
            cmd = ["osc", "-A", apiurl] + cmd
        else:
            cmd = ["osc"] + cmd

    return lib.run_cmd(cmd, *args, **kwargs)


def get_remote_pkgs():
    print(f"OBS: getting packages in {proj}")
    ret = run_osc(["list", proj])
    return ret.output.rstrip().split("\n")


def get_package_version(package):
    feed = lib.args.feed
    print(f"{package}: getting OBS version")
    ret = run_osc(["list", proj, os.path.basename(package)])

    # Empty OBS package
    if ret.output == '\n':
        return "0"

    # Extract the version from the file list
    for line in ret.output.split('\n'):
        line = line.rstrip()

        if feed == "master" and package != "osmocom-master":
            # Use commit_*.txt
            if line.startswith("commit_") and line.endswith(".txt"):
                return line.split("_")[1].split(".")[0]
        else:
            # Use *.dsc
            if line.endswith(".dsc"):
                return line.split("_")[-1][:-4]

    lib.exit_error_cmd(ret, "failed to find package version on OBS by"
                       " extracting the version from the file list")


def create_package(package):
    print(f"{package}: creating new OBS package")

    # cut off repository prefix like in "python/osmo-python-tests"
    package = os.path.basename(package)

    path_meta = f"{lib.config.path_temp}/_meta"
    path_meta_obs = f"source/{proj}/{package}/_meta"

    with open(path_meta, "w") as f:
        f.write(f'<package name="{package}" project="{proj}">\n')
        f.write(f'<title>{package}</title>\n')
        f.write('<description></description>\n')
        f.write('</package>\n')

    run_osc(["api", "-X", "PUT", "-T", path_meta, path_meta_obs])

    os.unlink(path_meta)


def remove_temp_osc():
    lib.run_cmd(["rm", "-rf", f"{lib.config.path_temp}/osc"])


def update_package(package, version):
    print(f"{package}: updating OBS package")

    # cut off repository prefix like in "python/osmo-python-tests"
    package = os.path.basename(package)

    path_output = lib.get_output_path(package)
    path_temp_osc = f"{lib.config.path_temp}/osc"
    path_temp_osc_pkg = f"{path_temp_osc}/{proj}/{package}"

    remove_temp_osc()
    os.makedirs(path_temp_osc)

    run_osc(["checkout", proj, package], cwd=path_temp_osc)

    if glob.glob(f"{path_temp_osc_pkg}/*"):
        run_osc("del *", shell=True, cwd=path_temp_osc_pkg)

    lib.run_cmd(f"mv * {shlex.quote(path_temp_osc_pkg)}", shell=True,
                cwd=path_output)

    run_osc("add *", shell=True, cwd=path_temp_osc_pkg)
    run_osc(["commit", "-m", f"upgrade to {version}"], cwd=path_temp_osc_pkg)

    remove_temp_osc()


def delete_package(package, commit_msg):
    print(f"{package}: removing from OBS ({commit_msg})")
    run_osc(["rdelete", "-m", commit_msg, proj, os.path.basename(package)])


def get_prjconf(output_file):
    print(f"{proj}: getting prjconf")
    prjconf = lib.osc.run_osc(["meta", "prjconf", proj]).output
    with open(output_file, "w") as h:
        h.write(prjconf)


def update_prjconf(prjconf_file, commit_msg):
    print(f"{proj}: updating prjconf")
    lib.osc.run_osc(["meta",
                     "prjconf",
                     "-F", prjconf_file,
                     "-m", commit_msg,
                     proj])


def get_meta(output_file):
    print(f"{proj}: getting meta")
    meta = lib.osc.run_osc(["meta", "prj", proj]).output
    with open(output_file, "w") as h:
        h.write(meta)


def update_meta(meta_file, commit_msg):
    print(f"{proj}: updating meta")
    lib.osc.run_osc(["meta",
                     "prj",
                     "-F", meta_file,
                     "-m", commit_msg,
                     proj])

def get_projects():
    print(f"OBS: getting list of projects")
    return lib.osc.run_osc(["ls"]).output.rstrip().split("\n")
