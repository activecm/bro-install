#!/bin/sh
IFACE="eth1"

for mode in rx tx sg tso gso gro ; do ethtool -K $IFACE $mode off; done

