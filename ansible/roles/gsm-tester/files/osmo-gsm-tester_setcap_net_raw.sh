#!/bin/sh

/sbin/setcap cap_net_raw+ep "$1"
