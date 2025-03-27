#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>

import glob
import os
import shlex
import sys
import lib
import lib.config
import xml.etree.ElementTree

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

    print(f"{package}: WARNING: failed to find package version on OBS!")
    print(f"{package}: assuming the package is outdated")
    return "0"


def get_package_sources(package, rev=None):
    # Use the API directly, because "osc list" throws an exception when trying
    # to list a directory with deleted files.
    url = f"/source/{proj}/{os.path.basename(package)}"
    if rev:
        url = f"{url}?rev={rev}"

    osc_ret = run_osc(["api", url])
    root = xml.etree.ElementTree.fromstring(osc_ret.output)

    # === Output ===
    # <directory name="open5gs" rev="1012" vrev="1" srcmd5="d98c9f8faeada3e291aa2197ca7fda03">
    #   <entry name="open5gs_2.7.5.4648.7dfd.202503302026.dsc" md5="7101346f69282beda8c1e2c191fadd4e" size="2040" mtime="1743367015"/>
    #   <entry name="open5gs_2.7.5.4648.7dfd.202503302026.tar.xz" md5="71fc5f9a885204d38f712236684822ac" size="14531220" mtime="1743367016"/>
    # </directory

    # === Output with already deleted files ===
    # <directory name="open5gs" rev="1" vrev="1" srcmd5="bcd19a5960921d5e30e99d988fffbd15">
    #   <entry name="open5gs_2.4.8.202206260026.dsc" md5="bf154599a1493d23f2f7f8669c5adb7c" error="No such file or directory"/>
    #   <entry name="open5gs_2.4.8.202206260026.tar.xz" md5="3f26b59b342a35d80d5ac790ff0a8ff2" error="No such file or directory"/>
    # </directory>

    ret = []
    for entry in root.findall("entry"):
        ret += [f"{entry.get('md5')}-{entry.get('name')}"]
    return ret


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
    print(f"OBS: getting list of projects ({apiurl})")
    return lib.osc.run_osc(["ls"]).output.rstrip().split("\n")


def get_last_rev(package):
    print(f"OBS: getting latest revision of {proj}:{package}")

    url = f"/source/{proj}/{os.path.basename(package)}"
    osc_ret = run_osc(["api", url])
    root = xml.etree.ElementTree.fromstring(osc_ret.output)
    rev = root.get("rev")
    if rev:
        return int(rev)
    return 0
