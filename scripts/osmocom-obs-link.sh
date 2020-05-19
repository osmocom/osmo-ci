#!/bin/sh -x
# Building packages for CentOS requires some dependencies, that are only available in openSUSE. These packages are
# linked into the Osmocom repository, so they get built for CentOS as well. This script is a reference for all linked
# packages in the repository and can be executed once when creating a new repository (e.g. in home:USER:nightly for
# testing changes before applying them to network:osmocom:nightly).

PROJ="home:USER"

# osmo-sip-connector: depends on sofia-sip-ua-glib
osc linkpac openSUSE:Factory sofia-sip "$PROJ"

# osmo-pcap: depends on libzmq
osc linkpac openSUSE:Factory zeromq "$PROJ"
osc linkpac openSUSE:Factory libunwind "$PROJ"
osc linkpac openSUSE:Factory libsodium "$PROJ"
osc linkpac openSUSE:Factory openpgm "$PROJ"

# osmo-remsim: depends on libulfius
osc linkpac openSUSE:Factory ulfius "$PROJ"
osc linkpac openSUSE:Factory orcania "$PROJ"
osc linkpac openSUSE:Factory yder "$PROJ"

# osmo-remsim: depends on libcsv
osc linkpac openSUSE:Factory libcsv "$PROJ"

# libusrp: depends on fdupes
osc linkpac openSUSE:Factory fdupes "$PROJ"

# libusrp: depends on sdcc
osc linkpac openSUSE:Factory sdcc "$PROJ"
