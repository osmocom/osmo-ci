#!/bin/bash -e

ifname="$1"
netns="$2"
shift
shift



if [ -f "/var/run/netns/${netns}" ]; then
    echo "netns $netns already exists"
else
    echo "Creating netns $netns"
    ip netns add "$netns"
fi

if [ -d "/sys/class/net/${ifname}" ]; then
    echo "Moving iface $ifname to netns $netns"
    ip link set $ifname netns $netns
else
    ip netns exec $netns ls "/sys/class/net/${ifname}" >/dev/null && echo "iface $ifname already in netns $netns"
fi
