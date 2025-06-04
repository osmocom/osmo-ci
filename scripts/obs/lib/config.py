#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import os
import re

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
    "packaging",
    "setuptools",
]

feeds = [
    "2022q1",
    "2022q2",
    "2023q1",
    "latest",
    "master",
    "nightly",
]

# Osmocom projects: generated source packages will depend on a meta package,
# such as osmocom-nightly, osmocom-latest or osmocom-2022q1. This meta package
# prevents that packages from different feeds are mixed by accident.
# NOTE: Before adding new projects, add them to jobs/gerrit-verifications.yml
#       and ensure the rpm and deb packages build successfully in jenkins.
# NOTE: Consider whether new packages should be added to EXCLUDE_PACKAGES in
#       osmocom-obs-nightly-asan.yml.
projects_osmocom = [
    "osmocom-keyring",

    "erlang/osmo_dia2gsup",
    "erlang/osmo-epdg",
    "erlang/osmo-s1gw",
    "gapk",
    "libasn1c",
    "libgtpnl",
    "libosmo-abis",
    "libosmo-dsp",
    "libosmo-gprs",
    "libosmo-netif",
    "libosmo-pfcp",
    "libosmo-sigtran",
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
    "osmocom-bb",
    "python/osmo-python-tests",
    "python/pyosmocom",
    "rtl-sdr",
    "simtrace2",
    "strongswan-epdg",
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
    "strongswan-epdg": "https://gitea.osmocom.org/ims-volte-vowifi/strongswan-epdg",
    "libosmo-sccp-legacy": "https://gitea.osmocom.org/osmocom/libosmo-sccp-legacy",
}

git_branch_default = "master"
git_branch_other = {
    "open5gs": "main",
}

def tag_pattern(prefix: str = '',
                a: str = r'\d+',
                b: str = r'\.\d+',
                c: str = r'\.\d+') -> str:
    return rf'^{prefix}{a}{b}{c}$'

git_latest_tag_pattern_default = tag_pattern()
git_latest_tag_pattern_other = {
        "gapk": tag_pattern('v', c=r'(\.\d+)?'),
        "limesuite": tag_pattern('v'),
        "open5gs": tag_pattern('v'),
        "osmo-fl2k": tag_pattern('v'),
        "rtl-sdr": tag_pattern('v'),
        "strongswan-epdg": tag_pattern('osmo-epdg-', c=r'\.[0-9a-z]+'),
        "wireshark": tag_pattern('v', c=r'\.[0-9a-z]+'),
}

docker_distro_default = "debian:12"
docker_distro_other = [
    "almalinux:*",  # instead of centos (SYS#5818)
    "centos:7",  # SYS#6760
    "debian:*",
    "ubuntu:*",
]

#
# Options related to sync from build.opensuse.org (OS#6165)
#

sync_remove_paths = [
    # This path has a kernel-obs-build package that other OBS instances use to
    # build armv7l/hl packages, but we don't need it
    "OBS:DefaultKernel",
]

sync_set_maintainers = [
    "osmocom-jenkins",
]

# Distributions for which we want to make sure we add the latest release as
# soon as it is available in openSUSE's OBS
# https://osmocom.org/projects/cellular-infrastructure/wiki/Linux_Distributions
check_new_distros = [
    "Debian",
    "Raspbian",
    "Ubuntu",
]

check_new_distros_version_regex = re.compile(r'[0-9.]+$')
