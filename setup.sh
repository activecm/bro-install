#!/bin/sh

set -e

MAKE_FLAGS="-j$(nproc --all)"
apt-get update
#BRO deps
apt-get -y install cmake make gcc g++ flex bison libpcap-dev libssl-dev python-dev swig zlib1g-dev
#BRO optional deps
apt-get -y install libgeoip-dev curl git libgoogle-perftools-dev sendmail python-pip
#PF RING deps
apt-get -y install build-essential linux-headers-$(uname -r) libnuma-dev

#Install the geoip db
curl -O http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz
gunzip GeoLiteCity.dat.gz
mv GeoLiteCity.dat /usr/share/GeoIP/

#CAF is required for BRO
git clone -b '0.14.6' --single-branch --depth 1 https://github.com/actor-framework/actor-framework.git
cd actor-framework
./configure
make $MAKE_FLAGS
make test
make install
cd ..

#IPSumdump is an optional dependency for BRO
curl -O http://www.read.seas.harvard.edu/~kohler/ipsumdump/ipsumdump-1.86.tar.gz
tar -xzf ipsumdump-1.86.tar.gz
cd ipsumdump-1.86
./configure
make $MAKE_FLAGS
make install
cd ..

#PF Ring is for FAST packet captures
git clone -b '6.6.0' https://github.com/ntop/PF_RING.git

#Install kernel module
cd PF_RING/kernel
make $MAKE_FLAGS
make install
modprobe pf_ring enable_tx_capture=0 min_num_slots=32768
echo "pf_ring enable_tx_capture=0 min_num_slots=32768" >> /etc/modules

#Install userland libraries
#PF Ring library
cd ../userland/lib
./configure --prefix=/usr/local/pfring
make $MAKE_FLAGS
make install

#PF Ring version of libpcap
cd ../libpcap
./configure --prefix=/usr/local/pfring
make $MAKE_FLAGS
make install

#Install PF Ring's tcpdump
cd ../tcpdump
./configure --prefix=/usr/local/pfring
make $MAKE_FLAGS
make install

#Add PF Ring's executables to the PATH
echo 'PATH=$PATH:/usr/local/pfring/bin:/usr/local/pfring/sbin' >> /etc/bash.bashrc

#Get BRO
cd ../../../
git clone -b 'v2.5.1' --recursive https://github.com/bro/bro.git
cd bro
./configure --prefix=/usr/local/bro --with-pcap=/usr/local/pfring
make $MAKE_FLAGS
make install

#Add Bro's executables to the PATH
echo 'PATH=$PATH:/usr/local/bro/bin' >> /etc/bash.bashrc

#Install Bro plugin manager
pip install bro-pkg

#Install and configure interface-setup plugin
bro-pkg install --force bro-interface-setup
cat << EOF >> /usr/local/bro/etc/broctl.cfg
###############################################
# Interface Setup Plugin Options

#interfacesetup.enabled=1
# To change the default mtu that is configured
interfacesetup.mtu=1500

# To change the default commands that are used to bring up the interface
#interfacesetup.up_command=/sbin/ifconfig {interface} up mtu {mtu}
#interfacesetup.flags_command=/sbin/ethtool -K {interface} gro off lro off rx off tx off gso off

# For FreeBSD systems uncomment this line
#interfacesetup.flags_command=/sbin/ifconfig {interface} -rxcsum -txcsum -tso4 -tso6 -lro -rxcsum6 -txcsum6 -vlanhwcsum -vlanhwtso
EOF

echo.
echo "Please edit /usr/local/bro/etc/node.cfg. The worker config must set lb_method=pf_ring.
Additionally, you must specify how many capture processes to run with lb_procs.
See https://www.bro.org/sphinx/configuration/index.html"

echo.
echo "To tune your interfaces for monitoring edit /usr/local/bro/etc/broctl.cfg and uncomment 'interfacesetup.enabled=1'."

