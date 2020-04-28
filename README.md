# Bro-Install
An Installation Script for Bro IDS on Debian Based Systems

This script compiles Bro-IDS with PF_RING support on Debian based systems. It will also assist in setting up a clustered configuration.

Please note that this type of installation is intended where performance is key. The typical setup assumes that you have one or more interfaces dedicated to capturing traffic (i.e. receive only). These interfaces will be completely taken over for capturing traffic and won't be able to be used for any other purposes.

1. Run `sudo ./setup.sh`. This will install PF_RING to `/usr/local/pfring/` and Bro to `/usr/local/bro/`.
2. Run `sudo gen-node-cfg.sh` to automatically generate a `node.cfg` configuration file for your system.
3. Edit `broctl.cfg` in `/usr/local/bro/etc` to further tune your interfaces for performance. Uncomment the line `#interfacesetup.enabled=1` to enable.

## Resources:
- https://docs.zeek.org/en/master/quickstart/index.html
- https://docs.zeek.org/en/master/install/index.html
- https://docs.zeek.org/en/master/frameworks/geoip.html
- https://docs.zeek.org/en/master/configuration/index.html

## Verified Systems
This script has been tested on:
- Ubuntu 16.04 LTS

If you successfully use this script on your system, please submit a PR adding your OS to this list.
