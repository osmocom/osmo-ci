#!/usr/bin/env python3
# Copyright 2025 sysmocom - s.f.m.c. GmbH
# SPDX-License-Identifier: GPL-3.0-or-later
# Simple webserver to make Osmocom related coredumps available in LXCs. See
# ../README.md and OS#6769 for details.
import datetime
import fnmatch
import http.server
import json
import os
import shutil
import signal
import socket
import socketserver
import subprocess
import sys
import tempfile


NETDEV = "lxcbr0"
IP_PATTERN = "10.0.*"
PORT = 8042


def find_lxc_ip():
    cmd = ["ip", "-j", "-o", "-4", "addr", "show", "dev", NETDEV]
    p = subprocess.run(cmd, capture_output=True, text=True, check=True)
    ret = json.loads(p.stdout)[0]["addr_info"][0]["local"]
    if not fnmatch.fnmatch(ret, IP_PATTERN):
        print(f"ERROR: IP doesn't match pattern {IP_PATTERN}: {ret}")
        sys.exit(1)
    return ret


def executable_is_relevant(exe):
    basename = os.path.basename(exe)
    patterns = [
        "open5gs-*",
        "osmo-*",
    ]

    for pattern in patterns:
        if fnmatch.fnmatch(basename, pattern):
            return True

    return False


class CustomRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/core":
            # Check for any coredump within last 3 seconds
            since = (datetime.datetime.now() - datetime.timedelta(seconds=3)).strftime("%Y-%m-%d %H:%M:%S")
            cmd = ["coredumpctl", "-q", "-S", since, "--json=short", "-n1"]

            p = subprocess.run(cmd, capture_output=True, text=True)
            if p.returncode != 0:
                self.send_error(404, "No coredump found")
                return None

            # Check if the coredump executable is from osmo-*, open5gs-*, etc.
            coredump = json.loads(p.stdout)[0]
            if not executable_is_relevant(coredump["exe"]):
                self.send_error(404, "No coredump found")
                return None

            # Put coredump into a temporary file and return it
            with tempfile.TemporaryDirectory() as tmpdirname:
                core_path = os.path.join(tmpdirname, "core")
                cmd = [
                    "coredumpctl",
                    "dump",
                    "-q",
                    "-S",
                    since,
                    "-o",
                    core_path,
                    str(coredump["pid"]),
                    coredump["exe"],
                ]
                subprocess.run(cmd, stdout=subprocess.DEVNULL, check=True)

                with open(core_path, "rb") as f:
                    self.send_response(200)
                    self.send_header("X-Executable-Path", coredump["exe"])
                    self.end_headers()
                    self.wfile.write(f.read())
        else:
            self.send_error(404, "File Not Found")


def signal_handler(sig, frame):
    sys.exit(0)


def main():
    if not shutil.which("coredumpctl"):
        print("ERROR: coredumpctl not found!")
        sys.exit(1)

    ip = os.environ.get("LXC_HOST_IP") or find_lxc_ip()
    print(f"Listening on {ip}:{PORT}")
    signal.signal(signal.SIGINT, signal_handler)
    with socketserver.TCPServer((ip, PORT), CustomRequestHandler, False) as httpd:
        httpd.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        httpd.server_bind()
        httpd.server_activate()
        httpd.serve_forever()


if __name__ == "__main__":
    main()
