#!/bin/sh

set -e

MAKE_FLAGS="-j$(nproc --all)"
#BRO deps
apt-get -y install cmake make gcc g++ flex bison libpcap-dev libssl-dev python-dev swig zlib1g-dev
#BRO optional deps
apt-get -y install libgeoip-dev curl git libgoogle-perftools-dev 
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

#Make PF Ring's libpcap available to the compiler
echo "/usr/local/pfring/lib" >> /etc/ld.so.conf

#Install PF Ring's tcpdump
cd ../tcpdump
./configure --prefix=/usr/local/pfring
make $MAKE_FLAGS
make install

#Add PF Ring's executables to the PATH
echo 'PATH=$PATH:/usr/local/pfring/bin:/usr/local/pfring/sbin' >> /etc/bash.bashrc

#Get BRO
cd ../../
git clone -b 'v2.5.1' --recursive https://github.com/bro/bro.git
cd bro
./configure --prefix=/usr/local/bro --with-pcap=/usr/local/pfring/lib
make $MAKE_FLAGS
make install

#Add Bro's executables to the PATH
echo 'PATH=$PATH:/usr/local/bro/bin' >> /etc/bash.bashrc

echo "Please edit /usr/local/bro/etc/node.cfg. The worker config must set lb_method=pf_ring.
Additionally, you must specify how many capture processes to run with lb_procs.
See https://www.bro.org/sphinx/configuration/index.html"

echo "Additionally edit monitor-only.sh to use your monitoring interface.
After editing the file, copy it to /etc/network/if-up.d/, and bring the monitoring interface down and back up."
