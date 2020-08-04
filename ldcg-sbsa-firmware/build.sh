#!/bin/bash

BRANCH="qemu_sbsa_pseudo_static_v1"
SBSA_ACS_VER="20.03_REL2.4"

set -ex

trap failure_exit INT TERM ERR
trap cleanup_exit EXIT

cleanup_exit()
{
    rm -rf ${HOME}/.docker
}

failure_exit()
{
    # we failed
    cleanup_exit
}

rm -rf ${WORKSPACE}/*

# install build dependencies for QEMU and EDK2
sudo apt update
sudo apt -y --no-install-recommends install build-essential pkg-config python3 libpixman-1-dev libglib2.0-dev dosfstools

git clone --depth 1 https://github.com/qemu/qemu.git
git clone --depth 1 --recurse-submodules https://github.com/tianocore/edk2.git
git clone --depth 1 --recurse-submodules https://git.linaro.org/people/tanmay.jagdale/edk2-platforms.git -b $BRANCH
git clone --depth 1 --recurse-submodules https://github.com/tianocore/edk2-non-osi.git

# let build QEMU - just AArch64 target

cd qemu
./configure --target-list=aarch64-softmmu
make -j$(nproc)
cd ${WORKSPACE}

# let build EDK2 for SBSA reference platform

export PACKAGES_PATH=$WORKSPACE/edk2:$WORKSPACE/edk2-platforms:$WORKSPACE/edk2-non-osi
make -C edk2/BaseTools

source edk2/edksetup.sh
build -b RELEASE -a AARCH64 -t GCC5 -p edk2-platforms/Platform/Qemu/SbsaQemu/SbsaQemu.dsc -n 0

# build AcpiViewApp
build -a AARCH64 -t GCC5 -p edk2/ShellPkg/ShellPkg.dsc -m edk2/ShellPkg/Application/AcpiViewApp/AcpiViewApp.inf  -n 0

# copy resulting firmware and resize to 256MB images

cp Build/SbsaQemu/RELEASE_GCC5/FV/SBSA_FLASH[01].fd .
truncate -s 256M SBSA_FLASH[01].fd

# Fetch SBSA Architecture Compliance Suite

wget https://github.com/ARM-software/sbsa-acs/archive/v${SBSA_ACS_VER}.tar.gz
tar xf v${SBSA_ACS_VER}.tar.gz
cp sbsa-acs-${SBSA_ACS_VER}/prebuilt_images/v${SBSA_ACS_VER}/Sbsa.efi .

# Create 16MB hdd with one ESP partition

truncate -s 16M sda.raw
echo 'label:gpt' | /sbin/sfdisk sda.raw
echo ',,U;' |/sbin/sfdisk sda.raw

# We want to do some checks to autostart on boot
# first check ACPI tables against SBBR 1.2
# then run SBSA ACS
# so we run UEFI Shell as bootloader and then it will run tests via startup.nsh script
echo "fs0:\AcpiViewApp.efi -r 2" > startup.nsh
echo "fs0:\Sbsa.efi" >> startup.nsh

device=$(sudo kpartx -avs sda.raw | cut -d' ' -f3)
mkdir 1
sudo mkfs.vfat /dev/mapper/$device
sudo mount /dev/mapper/$device 1
sudo cp Sbsa.efi 1/
sudo cp Build/Shell/DEBUG_GCC5/AARCH64/AcpiViewApp.efi 1/
sudo cp startup.nsh 1/
sudo mkdir -p 1/efi/boot/
sudo cp Build/SbsaQemu/RELEASE_GCC5/AARCH64/Shell.efi 1/efi/boot/bootaa64.efi
sudo umount 1
sudo kpartx -d sda.raw

# run SBSA ACS in QEMU - 30s timeout should be enough

timeout 30 ./qemu/aarch64-softmmu/qemu-system-aarch64 \
-machine sbsa-ref \
-drive if=pflash,file=SBSA_FLASH0.fd,format=raw \
-drive if=pflash,file=SBSA_FLASH1.fd,format=raw \
-drive if=ide,file=sda.raw,format=raw \
-nographic

