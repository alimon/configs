#!/bin/bash

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

