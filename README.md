# Bro-Install
An Installation Script for Bro IDS on Debian Based Systems

This script creates a clustered installation of Bro-IDS on Debian based systems.

After running `setup.sh`, edit the files in `/usr/local/bro/etc` appropriately.

Additionally, you may wish to use `monitor-only.sh` to ensure your monitor interfaces
are properly tuned after each boot.

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
