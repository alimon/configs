#!/bin/sh
set -ex

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qq update
sudo apt-get -qq -y install python3 python3-pip srecord libffi-dev

# No git-lfs package in Ununtu Xenial, install manually from packagecloud.io
wget https://packagecloud.io/github/git-lfs/packages/ubuntu/xenial/git-lfs_2.11.0_amd64.deb/download.deb -O git-lfs_2.11.0_amd64.deb
sudo dpkg -i git-lfs_2.11.0_amd64.deb

sudo pip3 install cmake
pip3 install --user cryptography pyasn1 pyyaml jinja2 cbor

# Show filesystem layout and space
df -h

# List available toolchains
ls -l ${HOME}/srv/toolchain/

git lfs install

# Preclude spammy "advices"
git config --global advice.detachedHead false
