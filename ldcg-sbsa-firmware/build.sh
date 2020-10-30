#!/bin/bash

SBSA_ENTERPRISE_ACS_VER="v20.10_REL3.0"

set -ex

source common-code.sh

fetch_enterprise_acs()
{
    # Fetch SBSA Enterprise Architecture Compliance Suite

    git clone https://github.com/ARM-software/arm-enterprise-acs.git -b release
    cd arm-enterprise-acs/prebuilt_images/${SBSA_ENTERPRISE_ACS_VER}
    git lfs pull
    cd -
}

rm -rf ${WORKSPACE}/*

# install build dependencies for QEMU and EDK2
sudo apt update
sudo apt -y --no-install-recommends install build-essential pkg-config python3 \
         libpixman-1-dev libglib2.0-dev dosfstools git-lfs mtools ninja-build


fetch_code
fetch_enterprise_acs

build_qemu
build_edk2

# run SBSA Enterprise ACS in QEMU - in 10 minutes timeouts as there is a test which shutdowns

set +e # do not exit on error

for try in `seq 1 ${QEMU_RETRIES}`
do
    echo "Starting qemu for ${try} time"
    timeout --foreground ${QEMU_TIMEOUT} \
        ./qemu/build/aarch64-softmmu/qemu-system-aarch64 \
            -machine sbsa-ref \
            -drive if=pflash,file=SBSA_FLASH0.fd,format=raw \
            -drive if=pflash,file=SBSA_FLASH1.fd,format=raw \
            -drive if=ide,format=raw,file=arm-enterprise-acs/prebuilt_images/${SBSA_ENTERPRISE_ACS_VER}/luv-live-image-gpt.img \
            -nographic \
            -serial mon:stdio
done

# Grab ACS logs

echo "drive c:" >~/.mtoolsrc
echo "    file=\"$(realpath arm-enterprise-acs/prebuilt_images/${SBSA_ENTERPRISE_ACS_VER}/luv-live-image-gpt.img)\" offset=1048576" >>~/.mtoolsrc

mkdir -p logs
mcopy -s -v c:/ logs/
