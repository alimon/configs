#!/bin/bash

set -e

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="gawk diffstat unzip texinfo gcc-multilib build-essential chrpath socat cpio python python-pip python-pexpect python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping"

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

# Install ruamel.yaml
pip install --user --force-reinstall ruamel.yaml

git clone --depth=1 https://git.yoctoproject.org/git/poky -b ${BRANCH} && cd poky && git log -1
git clone --depth=1 ${LAYER_URL} -b ${LAYER_BRANCH:-$BRANCH} layer && cd layer && git log -1

cd poky
source oe-init-build-env

yocto-check-layer ${WORKSPACE}/layer
