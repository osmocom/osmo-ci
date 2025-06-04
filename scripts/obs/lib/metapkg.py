# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright 2022 sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
import os
import lib
import lib.config
import lib.debian
import lib.rpm_spec


def get_conflicts(pkgname):
    ret = []
    for f in lib.config.feeds:
        if "osmocom-{f}" == pkgname:
            continue
        ret += [f"osmocom-{f}"]
    return ret


def prepare_source_dir(pkgname):
    path = f"{lib.config.path_cache}/{pkgname}"

    if os.path.exists(path):
        lib.run_cmd(["rm", "-rf", path])

    os.makedirs(f"{path}/debian")
    os.makedirs(f"{path}/contrib")


def generate_debian_pkg(pkgname, version):
    path = f"{lib.config.path_cache}/{pkgname}"
    conflicts = get_conflicts(pkgname)

    with open(f"{path}/debian/control", "w") as f:
        f.write(f"Source: {pkgname}\n")
        f.write("Section: unknown\n")
        f.write("Priority: optional\n")
        f.write("Maintainer: Osmocom OBS scripts <info@osmocom.org>\n")
        f.write("Build-Depends: debhelper (>= 10)\n")
        f.write("Standards-Version: 3.9.8\n")
        f.write("\n")
        f.write(f"Package: {pkgname}\n")
        f.write("Depends: osmocom-keyring ${misc:Depends}\n")
        f.write("Architecture: any\n")
        f.write(f"Conflicts: {', '.join(conflicts)}\n")
        f.write(f"Description: Dummy package, conflicts with {conflicts}\n")

    with open(f"{path}/debian/changelog", "w") as f:
        f.write(f"{pkgname} ({version}) unstable; urgency=medium\n")
        f.write("\n")
        f.write(f"  * Dummy package, which conflicts with: {conflicts}\n")
        f.write("\n")
        f.write(" -- Osmocom OBS scripts <info@osmocom.org>  Tue, 25 Jul 2022"
                " 15:48:00 +0200\n")

    with open(f"{path}/debian/rules", "w") as f:
        f.write("#!/usr/bin/make -f\n")
        f.write("%:\n")
        f.write("\tdh $@\n")

    lib.run_cmd(["chmod", "+x", f"{path}/debian/rules"])

    with open(f"{path}/debian/compat", "w") as f:
        f.write("10\n")


def generate_rpm_spec(pkgname, version):
    print(f"{pkgname}: generating rpm spec file")
    path = f"{lib.config.path_cache}/{pkgname}/contrib/{pkgname}.spec.in"
    conflicts = get_conflicts(pkgname)

    with open(path, "w") as f:
        f.write(f"Name:    {pkgname}\n")
        f.write(f"Version: {version}\n")
        f.write(f"Summary: Dummy package, conflicts with: {conflicts}\n")
        f.write("Release: 0\n")
        f.write("License: AGPL-3.0-or-later\n")
        f.write("Group:   Hardware/Mobile\n")
        for conflict in conflicts:
            f.write(f"Conflicts: {conflict}\n")
        f.write("%description\n")
        f.write(f"Dummy package, which conflicts with: {conflicts}\n")
        f.write("%files\n")


def build():
    feed = lib.args.feed
    pkgname = lib.args.conflict_pkgname or f"osmocom-{feed}"
    conflict_version = lib.args.conflict_version
    version = conflict_version if conflict_version else lib.config.meta_package_version
    print(f"{pkgname}: generating meta package {version}")

    prepare_source_dir(pkgname)
    generate_debian_pkg(pkgname, version)

    os.makedirs(lib.get_output_path(pkgname))
    lib.remove_cache_extra_files()

    lib.debian.build_source_package(pkgname)
    lib.debian.move_files_to_output(pkgname)

    generate_rpm_spec(pkgname, version)
    lib.rpm_spec.copy_to_output(pkgname)

    lib.remove_cache_extra_files()
    return version
