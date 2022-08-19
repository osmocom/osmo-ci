#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import os
import glob
import lib.config


def extract_source(srcdir, bindir):
    tarball = glob.glob(f"{srcdir}/*.tar.*")[0]

    print(f"extracting {os.path.basename(tarball)}")
    lib.run_cmd(["tar", "-xf", tarball], cwd=bindir)

    return glob.glob(f"{bindir}/*/")[0]


def build(srcdir, jobs):
    bindir = f"{lib.config.path_temp}/binpkg"
    extractdir = extract_source(srcdir, bindir)

    lib.set_cmds_verbose(True)

    # install deps
    lib.run_cmd(["apt-get", "-y", "build-dep", "."], cwd=extractdir)

    print("running dpkg-buildpackage")
    lib.run_cmd(["dpkg-buildpackage", "-us", "-uc", f"-j{jobs}"],
                cwd=extractdir)
