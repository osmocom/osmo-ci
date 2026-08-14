#!/bin/sh -ex
# CI script that runs on patches sent to gerrit.

pytest -xvv
