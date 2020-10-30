#!/bin/bash

SBSA_ACS_VER="20.10_REL3.0"

set -ex

source common-code.sh

rm -rf ${WORKSPACE}/*

# install build dependencies for QEMU and EDK2
sudo apt update
sudo apt -y --no-install-recommends install build-essential pkg-config python3 \
                                            libpixman-1-dev libglib2.0-dev \
                                            dosfstools ninja-build python

fetch_code

build_qemu
build_edk2

mkdir ${WORKSPACE}/logs/

# Fetch SBSA Architecture Compliance Suite

wget https://github.com/ARM-software/sbsa-acs/archive/v${SBSA_ACS_VER}.tar.gz
tar xf v${SBSA_ACS_VER}.tar.gz
cp sbsa-acs-${SBSA_ACS_VER}/prebuilt_images/v${SBSA_ACS_VER}/Sbsa.efi .

# Create 16MB hdd with one ESP partition

truncate -s 16M sda.raw
echo 'label:gpt' | /sbin/sfdisk sda.raw
echo ',,U;' |/sbin/sfdisk sda.raw

# Create disk and populate it with needed software

device=$(sudo kpartx -avs sda.raw | cut -d' ' -f3)
mkdir 1
sudo mkfs.vfat /dev/mapper/$device
sudo mount /dev/mapper/$device 1
sudo cp Sbsa.efi 1/
sudo mkdir -p 1/efi/boot/
sudo cp Build/SbsaQemu/RELEASE_GCC5/AARCH64/Shell.efi 1/efi/boot/bootaa64.efi
sudo umount 1
sudo kpartx -d sda.raw

for sbsa_level in 3 4 5 6
do
    echo "fs0:\Sbsa.efi -l ${sbsa_level}" > startup.nsh

    device=$(sudo kpartx -avs sda.raw | cut -d' ' -f3)
    sudo mount /dev/mapper/$device 1
    sudo cp startup.nsh 1/
    sudo umount 1
    sudo kpartx -d sda.raw

# run SBSA ACS in QEMU - 30s timeout should be enough

    timeout 30 ./qemu/build/qemu-system-aarch64 \
    -machine sbsa-ref \
    -drive if=pflash,file=SBSA_FLASH0.fd,format=raw \
    -drive if=pflash,file=SBSA_FLASH1.fd,format=raw \
    -drive if=ide,file=sda.raw,format=raw \
    -serial mon:stdio \
    -nographic | tee logs/sbsa-acs-level${sbsa_level}.log
done
