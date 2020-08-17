#!/bin/sh
set -ex

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qq update
sudo apt-get -qq -y install cmake python3 python3-pip srecord

pip3 install --user cryptography pyasn1 pyyaml jinja2 cbor

# Show filesystem layout and space
df -h

# List available toolchains
ls -l ${HOME}/srv/toolchain/

# Preclude spammy "advices"
git config --global advice.detachedHead false
