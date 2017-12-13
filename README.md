# Bro-Install
An Installation Script for Bro IDS on Debian Based Systems

This script creates a clustered installation of Bro-IDS on Debian based systems.

Please note that this type of installation is intended where performance is key. The typical setup assumes that you have one or more interfaces dedicated to capturing traffic (i.e. receive only). These interfaces will be completely taken over for capturing traffic and won't be able to be used for any other purposes.

1. Run `sudo ./setup.sh`
2. Edit `node.cfg` and `broctl.cfg` in `/usr/local/bro/etc` appropriately

## Resources:
- https://www.bro.org/sphinx-git/quickstart/index.html
- https://www.bro.org/sphinx/install/install.html
- https://www.bro.org/sphinx/frameworks/geoip.html#geolocation
- https://www.bro.org/sphinx/configuration/index.html

## Verified Systems
This script has been tested on:
- Ubuntu 16.04 LTS

If you successfully use this script on your system, please submit a PR adding
your OS to this list.
