#!/bin/sh
set -ex

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qq update
sudo apt-get -qq -y install git-lfs python3 python3-pip srecord

sudo pip3 install cmake
pip3 install --user cryptography pyasn1 pyyaml jinja2 cbor

# Show filesystem layout and space
df -h

# List available toolchains
ls -l ${HOME}/srv/toolchain/

git lfs install

# Preclude spammy "advices"
git config --global advice.detachedHead false
