# testenv-coredump-helper

A simple webserver to make Osmocom related coredumps available in LXCs.

## Architecture

```
.-----------------------------------------------------------------------------.
| build host (build4)                             .--------------------------.|
|                                                 | LXC (deb12build-ansible) ||
|                                                 |                          ||
|               shell                             |  HTTP                    ||
| coredumpctl --------- testenv-coredump-helper ------------- testenv        ||
|                                                 |__________________________||
|_____________________________________________________________________________|
```

## What this script does

This role installs a systemd service running the script in
`files/testenv-coredump-helper.py`, which runs a HTTP server on port `8042` of
the `lxcbr0`'s IP (e.g. `10.0.3.1`) on the build host. The IP is detected
dynamically as it is random on each build host.

The HTTP server provides one GET endpoint `/core`. When it is requested (by
testenv running inside the LXC), the script runs `coredumpctl` with parameters
to check for any coredump within the last three seconds that was created for
any Osmocom specific program (starting with `osmo-*` or `open5gs-*`).

* If no matching coredump was found, it returns HTTP status code `404`.

* If a matching coredump was found, it returns HTTP status code `200`, sends
  the path to the executable in an `X-Executable-Path` header and sends the
  coredump itself as body.

The coredump and path to the executable are retrieved from `coredumpctl`. The
coredump is stored in a temporary file for the duration of the transfer.

## Client implementation

The clientside implementation is in `osmo-ttcn3-hacks.git`,
`_testenv/testenv/coredump.py` in the `get_from_coredumpctl_lxc_host()`
function.

## Maximum coredump size

The `testenv-coredump-helper` script does not limit the size of the coredump,
however a maximum size that `systemd-coredump` accepts can be configured in
`/etc/systemd/coredump.conf`.
