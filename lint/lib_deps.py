#!/usr/bin/python3
# Catch missing dependencies in debian/control for -dev packages, to prevent
# bugs like https://gerrit.osmocom.org/c/libosmo-abis/+/38982.

import os
import sys
import subprocess

# read -dev pkgs and their deps from debian/control
# find related .pc.in files
# - pc.in: look for @LIB... in Libs: and Libs.private:
# - pc.in: check if these are also in Requires / Requires.private
# - debian/control: check if these are also in the depends

def find_dev_subpkgs() -> dict[str, list[str]]:
    if not os.path.exists("debian/control"):
        print("debian/control not found, skipping check")
        sys.exit(0)

    ret = {}
    current_pkg = ""
    in_depends = False
    with open("debian/control") as h:
        for line in h:
            if line.startswith("Package:"):
                current_pkg = line.split(":")[1].strip()
                if current_pkg.endswith("-dev"):
                    ret[current_pkg] = []
                continue
            if line.startswith("Depends:"):
                in_depends = True
                line = line.split(":", 1)[1]
            elif not line.startswith(" ") and not line.startswith("\t"):
                in_depends = False
                continue

            if in_depends and current_pkg.endswith("-dev"):
                ret[current_pkg] += [line.strip().rstrip(",").split(" ", 1)[0]]

    return ret


def find_pc_in_files() -> list[str]:
    proc = subprocess.run(["find", "-name", "*.pc.in"], text=True, capture_output=True)
    ret = []
    for i in proc.stdout.split("\n"):
        if i:
            ret += [i]
    return ret


def find_dev_subpkg_by_pc_in(dev_subpkgs: dict[str, list[str]], pc_in_file: str) -> (str, list[str]):
    if len(dev_subpkgs) == 1:
        name = list(dev_subpkgs.keys())[0]
        deps = dev_subpkgs[name]
        return name, deps

    name = f"{os.path.basename(pc_in_file).replace('.pc.in', '')}-dev"
    if name in dev_subpkgs:
        return name, dev_subpkgs[name]

    print(f"FIXME: can't figure out subpackage related to {pc_in_file}")
    sys.exit(0)


def get_pc_in_field(pc_in_file: str, field: str) -> list[str]:
    with open(pc_in_file) as h:
        for line in h:
            if line.startswith(f"{field}:"):
                line = line.split(":", 1)[1].strip()
                if not line:
                    return []
                return line.replace(",", "").split(" ")
    return []


def pc_in_dep_to_dev_dep(dep, dev_deps):
    name = dep
    if dep.startswith("@") and dep.endswith("_PC@"):
        name = dep.replace("_PC@", "").replace("@", "")
        name = name.lower()

    name = name.replace("libosmocodec", "libosmocore")
    name = name.replace("libosmogsm", "libosmocore")

    combinations = [
            f"lib{name}-dev",
            f"{name}-dev",
            f"{name}-0-dev",
    ]

    for combination in combinations:
        if combination in dev_deps:
            return combination


def pc_in_dep_to_pc_in_file(dep, pc_in_files):
    for pc_in_file in pc_in_files:
        if os.path.basename(pc_in_file) == f"{dep}.pc.in":
            return pc_in_file


def print_check_line(pc_in_file: str, field: str, dep: str, dev_name: str, dev_dep=None, pc_in_provider=None):
    if dev_dep:
        print(f"[OK ] {os.path.basename(pc_in_file)}: '{field}: {dep}' -> {dev_name}: 'Depends: {dev_dep}'")
    elif pc_in_provider:
        print(f"[OK ] {os.path.basename(pc_in_file)}: '{field}: {dep}' -> {os.path.basename(pc_in_provider)} in same package")
    else:
        print(f"[NOK] {os.path.basename(pc_in_file)}: '{field}: {dep}'")
        print(f"      -> consider adding 'Depends: <name>-dev' to {dev_name} in debian/control")


def main():
    ret = 0

    dev_subpkgs = find_dev_subpkgs()
    if not dev_subpkgs:
        print("No -dev subpackages found in debian/control, nothing to do.")
        return 0

    pc_in_files = find_pc_in_files()
    if not pc_in_files:
        print("No .pc.in files found, nothing to do.")
        return 0

    for dev_name, dev_deps in dev_subpkgs.items():
        print(f"debian/control: {dev_name} Depends: {dev_deps}")

    for pc_in_file in pc_in_files:
        dev_name, dev_deps = find_dev_subpkg_by_pc_in(dev_subpkgs, pc_in_file)
        for field in ["Requires", "Requires.private"]:
            deps = get_pc_in_field(pc_in_file, field)
            for dep in deps:
                dev_dep = pc_in_dep_to_dev_dep(dep, dev_deps)
                if dev_dep:
                    print_check_line(pc_in_file, field, dep, dev_name, dev_dep)
                    continue

                pc_in_provider = pc_in_dep_to_pc_in_file(dep, pc_in_files)
                if pc_in_provider:
                    print_check_line(pc_in_file, field, dep, dev_name, pc_in_provider=pc_in_provider)
                    continue

                # not found
                print_check_line(pc_in_file, field, dep, dev_name)
                ret = 1

    return ret


sys.exit(main())
