#!/bin/bash

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

    export PACKAGES_PATH=$WORKSPACE/edk2:$WORKSPACE/edk2-platforms:$WORKSPACE/edk2-non-osi:$WORKSPACE/edk2-libc
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
    git clone --depth 1 https://github.com/tianocore/edk2-platforms.git
    git clone --depth 1 https://github.com/tianocore/edk2-non-osi.git
    git clone --depth 1 https://github.com/tianocore/edk2-libc.git
    git clone --depth 1 https://git.linaro.org/ci/job/configs.git
}

build_sbsa_acs()
{

    cd edk2
    patch -p0 < ../configs/ldcg-sbsa-firmware/enable-sbsa-acs.patch

    cd ShellPkg/Application
    git clone --depth 1 https://github.com/ARM-software/sbsa-acs.git

    cd $WORKSPACE
    export GCC49_AARCH64_PREFIX=$GCC5_AARCH64_PREFIX
    source edk2/ShellPkg/Application/sbsa-acs/tools/scripts/avsbuild.sh
}

rm -rf ${WORKSPACE}/*

# install build dependencies for QEMU and EDK2
sudo apt update
sudo apt -y --no-install-recommends install build-essential pkg-config python3 \
                                            libpixman-1-dev libglib2.0-dev \
                                            dosfstools ninja-build python

fetch_code

build_qemu
build_edk2
build_sbsa_acs

mkdir -p ${WORKSPACE}/logs/

# Create 16MB hdd with one ESP partition

truncate -s 16M sda.raw
echo 'label:gpt' | /sbin/sfdisk sda.raw
echo ',,U;' |/sbin/sfdisk sda.raw

# Create disk and populate it with needed software

mkdir -p efi/boot
cp Build/SbsaQemu/RELEASE_GCC5/AARCH64/Shell.efi efi/boot/bootaa64.efi

echo "drive c:" >~/.mtoolsrc
echo "     file=\"${WORKSPACE}/sda.raw\" offset=1048576" >>~/.mtoolsrc

mformat c:
mcopy -s efi ./Build/Shell/DEBUG_GCC49/AARCH64/Sbsa.efi c:

for sbsa_level in 3 4 5 6
do
    echo "fs0:\Sbsa.efi -l ${sbsa_level}" > startup.nsh

    if [ "$sbsa_level" != "3" ]; then
        mdel c:startup.nsh
    fi
    mcopy startup.nsh c:

# run SBSA ACS in QEMU

    timeout --foreground ${QEMU_TIMEOUT} ./qemu/build/qemu-system-aarch64 \
    -machine sbsa-ref \
    -cpu cortex-a72 \
    -drive if=pflash,file=SBSA_FLASH0.fd,format=raw \
    -drive if=pflash,file=SBSA_FLASH1.fd,format=raw \
    -drive if=ide,file=sda.raw,format=raw \
    -serial mon:stdio \
    -nographic | tee logs/sbsa-acs-level${sbsa_level}.log

    timeout --foreground ${QEMU_TIMEOUT} ./qemu/build/qemu-system-aarch64 \
    -machine sbsa-ref \
    -cpu cortex-a72 \
    -watchdog-action none \
    -drive if=pflash,file=SBSA_FLASH0.fd,format=raw \
    -drive if=pflash,file=SBSA_FLASH1.fd,format=raw \
    -drive if=ide,file=sda.raw,format=raw \
    -serial mon:stdio \
    -nographic | tee logs/sbsa-acs-level${sbsa_level}-no-watchdog-reset.log
done
