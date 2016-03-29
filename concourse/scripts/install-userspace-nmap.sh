#!/bin/bash -eu

mkdir -p portable/debs
cd portable/debs
apt-get download nmap liblua5.2 liblinear1 libblas3
cd ..
for file in debs/*.deb
    do
        ar x $file && tar xvf data.tar.* && rm control.tar.* && rm data.tar.* && rm debian-binary
    done
cd ..
export LD_LIBRARY_PATH=$HOME/portable/usr/lib/:$HOME/portable/usr/lib/x86_64-linux-gnu:$HOME/portable/usr/lib/libblas
export PATH=$PATH:$HOME/portable/usr/bin/
