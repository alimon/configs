#!/bin/sh
set -ex

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qq update
sudo apt-get -qq -y install python3 python3-pip srecord libffi-dev libssl-dev

# No git-lfs package in Ununtu Xenial, install manually from packagecloud.io
wget https://packagecloud.io/github/git-lfs/packages/ubuntu/xenial/git-lfs_2.11.0_amd64.deb/download.deb -O git-lfs_2.11.0_amd64.deb
sudo dpkg -i git-lfs_2.11.0_amd64.deb

sudo pip3 install cmake
pip3 install --user cryptography pyasn1 pyyaml jinja2 cbor

if [ ! -d ${HOME}/srv/toolchain/gcc-arm-none-eabi-9-2019-q4-major ]; then
    wget -q https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/9-2019q4/RC2.1/gcc-arm-none-eabi-9-2019-q4-major-x86_64-linux.tar.bz2
    tar -xaf gcc-arm-none-eabi-9-2019-q4-major-x86_64-linux.tar.bz2 -C ${HOME}/srv/toolchain/
fi

# Show filesystem layout and space
df -h

# List available toolchains
ls -l ${HOME}/srv/toolchain/

git lfs install

# Preclude spammy "advices"
git config --global advice.detachedHead false
