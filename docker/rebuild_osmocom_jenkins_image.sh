#!/bin/sh
# In case the debian apt archive has become out of sync, try a --no-cache build if it fails.
docker build -t osmocom:amd64 -f Dockerfile_osmocom_jenkins.amd64 . \
 || docker build --no-cache -t osmocom:amd64 -f Dockerfile_osmocom_jenkins.amd64 .
