#!/bin/bash

SBSA_ENTERPRISE_ACS_VER="v20.10_REL3.0"

set -ex

build_qemu()
{
    # Build QEMU - only AArch64 target

    cd qemu
    ./configure --target-list=aarch64-softmmu
    make -j$(nproc)
    cd -
}

build_edk2()
{
    # Build EDK2 and truncate results to expected 256M

    export PACKAGES_PATH=$WORKSPACE/edk2:$WORKSPACE/edk2-platforms:$WORKSPACE/edk2-non-osi
    make -C edk2/BaseTools

    export GCC5_AARCH64_PREFIX=aarch64-linux-gnu-

    source edk2/edksetup.sh
    build -b RELEASE -a AARCH64 -t GCC5 -p edk2-platforms/Platform/Qemu/SbsaQemu/SbsaQemu.dsc -n 0

    # copy resulting firmware and resize to 256MB images

    cp Build/SbsaQemu/RELEASE_GCC5/FV/SBSA_FLASH[01].fd .
    truncate -s 256M SBSA_FLASH[01].fd
}

fetch_code()
{
    git clone --depth 1 https://github.com/qemu/qemu.git
    git clone --depth 1 --recurse-submodules https://github.com/tianocore/edk2.git
    git clone --depth 1 --recurse-submodules https://github.com/tianocore/edk2-platforms.git
    git clone --depth 1 --recurse-submodules https://github.com/tianocore/edk2-non-osi.git
}


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
            -cpu cortex-a72 \
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
