# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import os
import shutil
import subprocess
import sys
import lib
import lib.config


def get_image_name(distro, image_type):
    ret = f"{distro}-osmocom-obs-{image_type}"
    ret = ret.replace(":","-").replace("_","-")
    return ret


def build_image(distro, image_type):
    image_name = get_image_name(distro, image_type),
    print(f"docker: building image {image_name}")
    lib.run_cmd(["docker", "build",
                 "--build-arg", f"DISTRO={distro}",
                 "--build-arg", f"UID={os.getuid()}",
                 "-t", get_image_name(distro, image_type),
                 "-f", f"{lib.config.path_top}/data/{image_type}.Dockerfile",
                 f"{lib.config.path_top}/data"])


def get_oscrc():
    ret = os.path.expanduser("~/.oscrc")
    if "OSCRC" in os.environ:
        ret = os.environ["OSCRC"]

    if os.path.exists(ret):
        return os.path.realpath(ret)

    print("ERROR: couldn't find ~/.oscrc. Put it there or set OSCRC.")
    exit(1)


def run_in_docker_and_exit(script_path, add_oscrc=False,
                           image_type="build_srcpkg", distro=None):
    """
    :param script_path: what to run inside docker
    :param add_oscrc: put user's oscrc in docker (contains obs credentials!)
    :param image_type: which Dockerfile to use (data/{image_type}.Dockerfile)
    :param distro: which Linux distribution to use, e.g. "debian:11"
    """
    if "INSIDE_DOCKER" in os.environ:
        return

    if not shutil.which("docker"):
        print("ERROR: docker is not installed")
        exit(1)

    if not distro:
        distro = lib.config.docker_distro_default
    image_name = get_image_name(distro, image_type)

    oscrc = None
    if add_oscrc:
        oscrc = get_oscrc()

    # Build the docker image. Unless it is up-to-date, this will take a few
    # minutes or so, therefore print the output. No need to restore
    # set_cmds_verbose, as we use subprocess.run() below and exit afterwards.
    lib.set_cmds_verbose(True)
    build_image(distro, image_type)

    cmd = ["docker", "run",
           "--rm",
           "-e", "INSIDE_DOCKER=1",
           "-e", "PYTHONUNBUFFERED=1",
           "-v", f"{lib.config.path_top}:/obs"]

    if oscrc:
        cmd += ["-v", f"{oscrc}:/home/user/.oscrc"]

    script_path = f"/obs/{os.path.basename(script_path)}"
    cmd += [image_name, script_path] + sys.argv[1:]

    print(f"docker: running: {os.path.basename(script_path)} inside docker")
    ret = subprocess.run(cmd)
    exit(ret.returncode)
