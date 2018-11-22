# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2018 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>

# Where to clone sources from (with trailing slash)
git_url_prefix = "git://git.osmocom.org/"

# Default projects to build when none are specified on the command line
projects = ("osmo-bts",
            "osmo-pcu",
            "osmo-hlr",
            "osmo-mgw",
            "osmo-msc",
            "osmo-sysmon",
            "osmo-sgsn",
            "osmo-ggsn")

# Libraries coming from Osmocom repositories (glob patterns)
# All other libraries (e.g. libsystemd) are ignored by this script, even if
# they are mentioned with PKG_CHECK_MODULES in configure.ac.
relevant_library_patterns = ("libasn1c",
                             "libgtp",
                             "libosmo*")


# Library locations in the git repositories
# Libraries that have the same name as the git repository don't need to be
# listed here. Left: repository name, right: libraries
repos = {"libosmocore": ("libosmocodec",
                         "libosmocoding",
                         "libosmoctrl",
                         "libosmogb",
                         "libosmogsm",
                         "libosmosim",
                         "libosmovty"),
         "libosmo-abis": ("libosmoabis",
                          "libosmotrau"),
         "libosmo-sccp": ("libosmo-mtp",
                          "libosmo-sigtran",
                          "libosmo-xua"),
         "osmo-ggsn": ("libgtp"),
         "osmo-hlr": ("libosmo-gsup-client"),
         "osmo-iuh": ("libosmo-ranap"),
         "osmo-mgw": ("libosmo-mgcp-client",
                      "libosmo-legacy-mgcp")}
