# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import os
import shutil
import subprocess
import sys
import lib
import lib.config


def build_image():
    print(f"docker: building image {lib.config.docker_image_name}")
    lib.run_cmd(["docker", "build",
                 "--build-arg", f"UID={os.getuid()}",
                 "-t", lib.config.docker_image_name,
                 f"{lib.config.path_top}/data"])


def get_oscrc():
    ret = os.path.expanduser("~/.oscrc")
    if "OSCRC" in os.environ:
        ret = os.environ["OSCRC"]

    if os.path.exists(ret):
        return os.path.realpath(ret)

    print("ERROR: couldn't find ~/.oscrc. Put it there or set OSCRC.")
    exit(1)


def run_in_docker_and_exit(script_path, args, add_oscrc=False):
    if "INSIDE_DOCKER" in os.environ:
        return

    if not shutil.which("docker"):
        print("ERROR: docker is not installed")
        exit(1)

    oscrc = None
    if add_oscrc:
        oscrc = get_oscrc()

    # Build the docker image. Unless it is up-to-date, this will take a few
    # minutes or so, therefore print the output.
    lib.set_cmds_verbose(True)
    build_image()
    lib.set_cmds_verbose(args.verbose)

    cmd = ["docker", "run",
           "--rm",
           "-e", "INSIDE_DOCKER=1",
           "-e", "PYTHONUNBUFFERED=1",
           "-v", f"{lib.config.path_top}:/obs"]

    if oscrc:
        cmd += ["-v", f"{oscrc}:/home/user/.oscrc"]

    script_path = f"/obs/{os.path.basename(script_path)}"
    cmd += [lib.config.docker_image_name, script_path] + sys.argv[1:]

    print(f"docker: running: {os.path.basename(script_path)} inside docker")
    ret = subprocess.run(cmd)
    exit(ret.returncode)
