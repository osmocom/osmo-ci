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


def get_distro_from(distro, image_type):
    # Manuals: depend on regular image (data/build_binpkg_manuals.Dockerfile)
    if image_type.endswith("_manuals"):
        return get_image_name(distro, image_type.replace("_manuals", ""))

    # Ensure we can use short names like "debian:13" instead of "debian:trixie"
    # even though upstream apparently doesn't push the number-tags anymore:
    # https://hub.docker.com/_/debian
    match distro:
        case "debian:10":
            distro = "debian/eol:buster"
        # debian:11 points to debian:bullseye upstream
        # debian:12 points to debian:bookworm upstream
        case "debian:13":
            distro = "debian:trixie"

    return distro


def build_image(distro, image_type):
    image_name = get_image_name(distro, image_type)
    distro_from = get_distro_from(distro, image_type)

    print(f"docker: building image {image_name}")

    # Set the feed of packages to be configured inside the docker container
    # (master, nightly, latest). This can be set with build_binpkg.py --feed,
    # to reproduce a build error that happens with a distro that is only in
    # nightly but not in the master feed (all ubuntu versions as of writing).
    build_arg_feed = []
    if getattr(lib.args, "docker_feed", None):
        build_arg_feed = ["--build-arg", f"FEED={lib.args.docker_feed}"]

    lib.run_cmd(["docker", "build",
                 "--build-arg", f"DISTRO={distro}",
                 "--build-arg", f"DISTRO_FROM={distro_from}",
                 "--build-arg", f"UID={os.getuid()}"] +
                build_arg_feed +
                ["-t", image_name,
                 "-f", f"{lib.config.path_top}/data/{image_type}.Dockerfile",
                 f"{lib.config.path_top}/data"])


def get_oscrc():
    ret = os.path.expanduser("~/.oscrc")
    if "OSCRC" in os.environ:
        ret = os.environ["OSCRC"]

    if os.path.exists(ret):
        return os.path.realpath(ret)

    print("ERROR: couldn't find ~/.oscrc. Put it there or set OSCRC.")
    sys.exit(1)


def run_in_docker_and_exit(script_path, add_oscrc=False,
                           image_type="build_srcpkg", distro=None,
                           pass_argv=True, env={}, docker_args=[]):
    """
    :param script_path: what to run inside docker, relative to scripts/obs/
    :param add_oscrc: put user's oscrc in docker (contains obs credentials!)
    :param image_type: which Dockerfile to use (data/{image_type}.Dockerfile)
    :param distro: which Linux distribution to use, e.g. "debian:11"
    :param pass_argv: pass arguments from sys.argv to the script
    :param env: dict of environment variables
    :param docker_args: extra arguments to pass to docker
    """
    if "INSIDE_DOCKER" in os.environ:
        return

    if not shutil.which("docker"):
        print("ERROR: docker is not installed")
        sys.exit(1)

    if not distro:
        distro = lib.config.docker_distro_default
    image_name = get_image_name(distro, image_type)

    oscrc = None
    if add_oscrc:
        oscrc = get_oscrc()

    # Unless the docker image is up-to-date, building will take a few
    # minutes or so, therefore print the output. No need to restore
    # set_cmds_verbose, as we use subprocess.run() below and exit afterwards.
    lib.set_cmds_verbose(True)

    # Manuals: build regular image first (data/build_binpkg_manuals.Dockerfile)
    if image_type.endswith("_manuals"):
        build_image(distro, image_type.replace("_manuals",""))

    build_image(distro, image_type)

    pip_cache = os.path.join(os.environ['HOME'], ".cache/pip")
    os.makedirs(pip_cache, exist_ok=True)

    cmd = ["docker", "run",
           "--rm",
           "-e", "INSIDE_DOCKER=1",
           "-e", "PYTHONUNBUFFERED=1",
           "-v", f"{lib.config.path_top}:/obs",
           "-v", f"{pip_cache}:/home/user/.cache/pip"]

    for env_key, env_val in env.items():
        cmd += ["-e", f"{env_key}={env_val}"]

    if oscrc:
        cmd += ["-v", f"{oscrc}:/home/user/.oscrc"]

    cmd += docker_args
    cmd += [image_name, f"/obs/{script_path}"]

    if pass_argv:
        cmd += sys.argv[1:]

    print(f"docker: running: {script_path} inside docker")
    ret = subprocess.run(cmd)
    sys.exit(ret.returncode)
