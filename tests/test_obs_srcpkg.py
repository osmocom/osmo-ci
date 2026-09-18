import argparse
import os
import sys

sys.path.append(os.path.realpath(os.path.dirname(__file__) + "/../scripts/obs"))

import lib.srcpkg


def test_obs_srcpkg_get_version_epoch(monkeypatch):
    # Mock args
    parser = argparse.ArgumentParser()
    parser.add_argument("--version-append")
    monkeypatch.setattr(sys, "argv", ["test"])
    monkeypatch.setattr(lib, "args", parser.parse_args())

    # Mock functions for getting version from debian changelog / git
    version_changelog = None
    version_for_feed = None

    def get_last_version_from_changelog(project):
        return version_changelog

    def get_version_for_feed(project):
        return version_for_feed

    monkeypatch.setattr(lib.debian, "get_last_version_from_changelog", get_last_version_from_changelog)
    monkeypatch.setattr(lib.srcpkg, "get_version_for_feed", get_version_for_feed)

    #
    # Run get_version_epoch() (prints are for "pytest -s")
    #

    print("\n*** changelog > git version")
    func = lib.srcpkg.get_version_epoch
    project = "osmo-iuh"
    version_changelog = "1.8.1"
    version_for_feed = "1.8.0.6-2b92"
    assert ("1.8.1", None) == func(project)

    print("\n*** changelog > git version + epoch in changelog")
    project = "osmo-gbproxy"
    version_changelog = "1:0.5.2"
    version_for_feed = "0.5.1.1-422ff"
    assert ("0.5.2", "1") == func(project)

    print("\n*** changelog < git version")
    project = "osmo-iuh"
    version_changelog = "1.8.0"
    version_for_feed = "1.8.0.6-2b92"
    assert ("1.8.0.6-2b92", None) == func(project)

    print("\n*** unknown git version")
    project = "test"
    version_changelog = "1.8.0"
    version_for_feed = None
    assert ("1.8.0", None) == func(project)

    print("\n*** invalid changelog version")
    project = "test"
    version_changelog = "some-invalid-version"
    version_for_feed = "1.8.0"
    assert ("1.8.0", None) == func(project)

    print("\n*** changelog < git version + version append")
    project = "test"
    version_changelog = "1.0.0"
    version_for_feed = "1.0.0.1-c0ff33"
    monkeypatch.setattr(lib.args, "version_append", "~test")
    assert ("1.0.0.1-c0ff33~test", None) == func(project)
