#!/bin/bash

set -e

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="python-pip chrpath cpio diffstat gawk libmagickwand-dev libmath-prime-util-perl libsdl1.2-dev libssl-dev python-requests texinfo vim-tiny whiptail"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

# Install ruamel.yaml
pip install --user --force-reinstall ruamel.yaml

set -ex

git clone --depth=1 https://git.yoctoproject.org/git/poky -b ${BRANCH}
git clone --depth=1 ${LAYER_URL} -b ${LAYER_BRANCH} layer

cd poky
source oe-init-build-env

yocto-check-layer ${WORKSPACE}/layer
