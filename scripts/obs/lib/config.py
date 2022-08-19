#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import os

# Lists are ordered alphabetically.

path_top = os.path.normpath(f"{os.path.realpath(__file__)}/../..")
path_cache = f"{path_top}/_cache"
path_temp = f"{path_top}/_temp"

# Keep in sync with packages installed in data/Dockerfile
required_programs = [
    "dh",
    "dh_python3",
    "dpkg-buildpackage",
    "fakeroot",
    "find",
    "git",
    "git-review",
    "meson",
    "osc",
    "rebar3",
    "sed",
]

required_python_modules = [
    "setuptools",
]

feeds = [
    "2022q1",
    "2022q2",
    "latest",
    "master",
    "nightly",
]

# Osmocom projects: generated source packages will depend on a meta package,
# such as osmocom-nightly, osmocom-latest or osmocom-2022q1. This meta package
# prevents that packages from different feeds are mixed by accident.
# NOTE: Before adding new projects, make sure the rpm and deb build in OBS!
#       Test it in your own namespace (home:youruser), see README for
#       instructions and/or ask osmith for help.
projects_osmocom = [
    "erlang/osmo_dia2gsup",
    "libasn1c",
    "libgtpnl",
    "libosmo-abis",
    "libosmo-dsp",
    "libosmo-gprs",
    "libosmo-netif",
    "libosmo-pfcp",
    "libosmo-sccp",
    "libosmocore",
    "libsmpp34",
    "libusrp",
    "osmo-bsc",
    "osmo-bsc-nat",
    "osmo-bts",
    "osmo-cbc",
    "osmo-e1d",
    "osmo-fl2k",
    "osmo-gbproxy",
    "osmo-ggsn",
    "osmo-gsm-manuals",
    "osmo-hlr",
    "osmo-hnbgw",
    "osmo-hnodeb",
    "osmo-iuh",
    "osmo-mgw",
    "osmo-msc",
    "osmo-pcap",
    "osmo-pcu",
    "osmo-remsim",
    "osmo-sgsn",
    "osmo-sip-connector",
    "osmo-smlc",
    "osmo-sysmon",
    "osmo-trx",
    "osmo-uecups",
    "osmo-upf",
    "python/osmo-python-tests",
    "rtl-sdr",
    "simtrace2",
]
projects_other = [
    "limesuite",
    "neocon",
    "open5gs",
]

git_url_default = "https://gerrit.osmocom.org"  # /project gets appended
git_url_other = {
    "libosmo-dsp": "https://gitea.osmocom.org/sdr/libosmo-dsp",
    "limesuite": "https://github.com/myriadrf/LimeSuite",
    "neocon": "https://github.com/laf0rge/neocon",
    "open5gs": "https://github.com/open5gs/open5gs",
    "osmo-fl2k": "https://gitea.osmocom.org/sdr/osmo-fl2k",
    "rtl-sdr": "https://gitea.osmocom.org/sdr/rtl-sdr",
}

git_branch_default = "master"
git_branch_other = {
    "open5gs": "main",
}

git_latest_tag_pattern_default = "^[0-9]*\\.[0-9]*\\.[0-9]*$"
git_latest_tag_pattern_other = {
        "limesuite": "^v[0-9]*\\.[0-9]*\\.[0-9]*$",
        "open5gs": "^v[0-9]*\\.[0-9]*\\.[0-9]*$",
}

docker_distro_default = "debian:11"
docker_distro_other = [
    "centos:8",
]
