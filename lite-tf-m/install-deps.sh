#!/bin/sh
set -ex

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qq update
sudo apt-get -qq -y install python3 python3-pip python3-setuptools srecord libffi-dev libssl-dev

# No git-lfs package in Ununtu Xenial, install manually from packagecloud.io
wget https://packagecloud.io/github/git-lfs/packages/ubuntu/xenial/git-lfs_2.11.0_amd64.deb/download.deb -O git-lfs_2.11.0_amd64.deb
sudo dpkg -i git-lfs_2.11.0_amd64.deb

# As a first step, upgrade pip itself. The one shipping with Ubuntu 18.04
# is rather old by now, and may have issues installing modern .whl packages.
sudo pip3 install -U pip
pip3 --version

sudo pip3 install cmake
pip3 install --user cryptography pyasn1 pyyaml jinja2 cbor

#TOOLCHAINS=${HOME}/srv/toolchain
TOOLCHAINS=${WORKSPACE}/srv/toolchain

if [ ! -d ${TOOLCHAINS}/gcc-arm-none-eabi-9-2019-q4-major ]; then
    mkdir -p ${TOOLCHAINS}
    wget -q https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/9-2019q4/RC2.1/gcc-arm-none-eabi-9-2019-q4-major-x86_64-linux.tar.bz2
    tar -xaf gcc-arm-none-eabi-9-2019-q4-major-x86_64-linux.tar.bz2 -C ${TOOLCHAINS}
fi

# Show filesystem layout and space
df -h

# List available toolchains
ls -l ${TOOLCHAINS}

git lfs install

# Preclude spammy "advices"
git config --global advice.detachedHead false
