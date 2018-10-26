#!/bin/bash
netns="$1"
shift
#TODO: Later on I may want to call myself with specific ENV and calling sudo in order to run inside the netns but with dropped privileges
ip netns exec $netns "$@"
