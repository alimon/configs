#!/bin/bash

export SNAP=$(mktemp -d /tmp/lite.XXXXXX)

echo "deb http://archive.ubuntu.com/ubuntu/ xenial-updates main universe" | sudo tee -a /etc/apt/sources.list
echo "deb http://archive.ubuntu.com/ubuntu/ xenial-proposed main universe" | sudo tee -a /etc/apt/sources.list

sudo apt -q=2 update
sudo apt -q=2 install -y --no-install-recommends dosfstools snapcraft snapd squashfs-tools ubuntu-image pxz

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
  cd ${WORKSPACE}
  sudo umount ${SNAP} || true
  sudo rm -rf ${SNAP} || true
  rm -f ubuntu-image_*
}

# sbin isn't in the PATH by default and prevent to find mkfs.vfat
export PATH="/usr/sbin:/sbin:$PATH"

tar xf snap.tar -C ${HOME}
wget -q https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/lite-gateway-ubuntu-core/pi-3.json -O pi-3.json
cat pi-3.json | snap sign -k madper-new &> pi-3.model

snap download ubuntu-image

sudo mount -o loop -t squashfs ubuntu-image_*.snap ${SNAP}
${SNAP}/command-ubuntu-image.wrapper -c beta -o pi-3.img pi-3.model
