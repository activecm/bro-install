#!/bin/sh

MONITORS="eth0"

for monitor in $MONITORS; do
  if [ $IFACE = $monitor ]; then
    for mode in rx tx sg tso gso gro ; do ethtool -K $IFACE $mode off; done
    exit 0
  fi
done
