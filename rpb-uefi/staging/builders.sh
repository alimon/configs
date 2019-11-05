#!/bin/bash

export JOB_NAME=96boards-reference-uefi
echo "JOB_URL: ${JOB_URL}"
echo "BUILD_URL: ${BUILD_URL}"
echo "WORKSPACE: ${WORKSPACE}"
echo "BUILD_NUMBER: ${BUILD_NUMBER}"

# Create lower case debug/release string for use in paths
BUILD_TYPE="${MX_TYPE,,}"

sudo apt-get update
sudo apt-get install -y libssl-dev nasm python-requests python-crypto python-wand zip

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    cd ${WORKSPACE}
    rm -rf arm-trusted-firmware
    rm -rf uefi-tools
    rm -rf l-loader
    rm -rf OpenPlatformPkg
    rm -rf optee_os
    rm -rf edk2/Build
}

# sbin isn't in the PATH by default and prevent to find sgdisk
export PATH="/usr/sbin:/sbin:$PATH"

# Use pre-installed linaro toolchain
export PATH="${HOME}/srv/toolchain/gcc-linaro-6.4.1-2017.08-x86_64_aarch64-linux-gnu/bin:$PATH"
export PATH="${HOME}/srv/toolchain/gcc-linaro-6.4.1-2017.08-x86_64_arm-linux-gnueabihf/bin:$PATH"

# Common git repositories to fetch
UEFI_TOOLS_GIT_URL=https://git.linaro.org/uefi/uefi-tools.git
UEFI_TOOLS_GIT_BRANCH=master
#EDK2_GIT_URL=https://github.com/tianocore/edk2.git
EDK2_GIT_URL=https://git.linaro.org/uefi/linaro-edk2.git
EDK2_GIT_VERSION=$EDK2_VERSION
ATF_GIT_URL=https://git.trustedfirmware.org/TF-A/trusted-firmware-a.git
ATF_GIT_VERSION=$ATF_VERSION
## Temporarily switch to a dev tree/branch
OPEN_PLATFORM_PKG_GIT_URL=https://git.linaro.org/uefi/OpenPlatformPkg.git
OPEN_PLATFORM_PKG_GIT_BRANCH=master
OPTEE_OS_GIT_URL=https://github.com/OP-TEE/optee_os.git
OPTEE_GIT_VERSION=$OPTEE_VERSION

# So we can easily identify the build number via build path
mkdir ${BUILD_NUMBER}; cd ${BUILD_NUMBER}

# Per board repositories overrides
case "${MX_PLATFORM}" in
    hikey|hikey960)
        EDK2_GIT_URL=https://github.com/96boards-hikey/edk2.git
        EDK2_GIT_VERSION="origin/testing/hikey960_v2.5"
        ATF_GIT_VERSION="origin/integration"
        OPEN_PLATFORM_PKG_GIT_URL=https://github.com/96boards-hikey/OpenPlatformPkg.git
        OPEN_PLATFORM_PKG_GIT_BRANCH="testing/hikey960_v1.3.4"
        L_LOADER_GIT_URL=https://github.com/96boards-hikey/l-loader.git
        L_LOADER_GIT_BRANCH="testing/hikey960_v1.2"
        ;;
esac

# Force cap GCC build profile to GCC5
TOOLCHAIN=GCC5
export AARCH64_TOOLCHAIN=GCC5

# Clone the repos
git clone -b $UEFI_TOOLS_GIT_BRANCH $UEFI_TOOLS_GIT_URL uefi-tools
cd uefi-tools; UEFI_TOOLS_GIT_VERSION=`git log --format="%H" -1`; cd ..

git clone $EDK2_GIT_URL edk2
cd edk2; git checkout -b stable-baseline $EDK2_GIT_VERSION
git submodule update --init --recursive
EDK2_GIT_VERSION=$(git rev-parse $EDK2_GIT_VERSION)
cd ..

git clone -b $OPEN_PLATFORM_PKG_GIT_BRANCH $OPEN_PLATFORM_PKG_GIT_URL OpenPlatformPkg
cd edk2; rm -rf OpenPlatformPkg; ln -s ../OpenPlatformPkg; cd ..
cd OpenPlatformPkg; OPEN_PLATFORM_PKG_GIT_VERSION=`git log --format="%H" -1`; cd ..

git clone $ATF_GIT_URL arm-trusted-firmware
cd arm-trusted-firmware; git checkout -b stable-baseline $ATF_GIT_VERSION;
ATF_GIT_VERSION=$(git rev-parse $ATF_GIT_VERSION)
cd ..

git clone $OPTEE_OS_GIT_URL optee_os
cd optee_os; git checkout -b stable-baseline $OPTEE_GIT_VERSION;
OPTEE_OS_GIT_VERSION=`git log --format="%H" -1`; cd ..

git clone --depth 1 https://github.com/96boards-hikey/atf-fastboot.git

# Build setup
export EDK2_DIR=${WORKSPACE}/${BUILD_NUMBER}/edk2
export OPP_DIR=${WORKSPACE}/${BUILD_NUMBER}/OpenPlatformPkg
export ATF_DIR=${WORKSPACE}/${BUILD_NUMBER}/arm-trusted-firmware
export OPTEE_OS_DIR=${WORKSPACE}/${BUILD_NUMBER}/optee_os
export UEFI_TOOLS_DIR=${WORKSPACE}/${BUILD_NUMBER}/uefi-tools

export BUILD_PATH=${WORKSPACE}/${BUILD_NUMBER}

# Build UEFI for the desired platform, with the specified build type
cd ${EDK2_DIR}

ln -sf ../OpenPlatformPkg

export LOADER_DIR=${BUILD_PATH}/l-loader

cd ${WORKSPACE}/${BUILD_NUMBER}
git clone --depth 1 -b ${L_LOADER_GIT_BRANCH} ${L_LOADER_GIT_URL} l-loader
cd $LOADER_DIR

sed -i "s/#GENERATE_PTABLE=1/GENERATE_PTABLE=1/g" build_uefi.sh
if [ "${BUILD_TYPE}" = "debug" ]; then
    sed -i "s/BUILD_OPTION=DEBUG/BUILD_OPTION=RELEASE/g" build_uefi.sh
fi

./build_uefi.sh  ${MX_PLATFORM}

cd ${WORKSPACE}
mkdir -p out/${BUILD_TYPE}

if [ "${MX_PLATFORM}" = "hikey" ]; then
    # Ship files needed to build OP-TEE test suite
    tar -C ${OPTEE_OS_DIR}/out -acvf \
      ${WORKSPACE}/out/${BUILD_TYPE}/optee-arm-plat-hikey.tar.xz \
      arm-plat-hikey/export-ta_arm64 arm-plat-hikey/export-ta_arm32
    wget https://raw.githubusercontent.com/96boards/burn-boot/master/hisi-idt.py -O ${WORKSPACE}/out/${BUILD_TYPE}/hisi-idt.py
    dd if=/dev/zero of=${WORKSPACE}/out/${BUILD_TYPE}/nvme.img bs=128 count=1024
    cp -L ${LOADER_DIR}/fip.bin ${LOADER_DIR}/l-loader.bin ${LOADER_DIR}/recovery.bin ${LOADER_DIR}/*ptable.img ${WORKSPACE}/out/${BUILD_TYPE}
fi

if [ "${MX_PLATFORM}" = "hikey960" ]; then
    cp -L ${LOADER_DIR}/fip.bin ${LOADER_DIR}/l-loader.bin ${LOADER_DIR}/recovery.bin ${LOADER_DIR}/*ptable.img ${WORKSPACE}/out/${BUILD_TYPE}
    git clone --depth 1 https://github.com/96boards-hikey/tools-images-hikey960.git
    cd tools-images-hikey960
    cat > config << EOF
hisi-sec_usb_xloader.img 0x00020000
hisi-sec_uce_boot.img 0x6A908000
recovery.bin 0x1AC00000
EOF
    cp -L config hikey_idt hisi-sec_uce_boot.img hisi-sec_usb_xloader.img hisi-sec_xloader.img ${WORKSPACE}/out/${BUILD_TYPE}/
fi

cd ${WORKSPACE}

cat > ${WORKSPACE}/out/${BUILD_TYPE}/BUILD-INFO.txt << EOF
Format-Version: 0.5

Files-Pattern: *
License-Type: open
EOF

# Create MD5SUMS file
(cd ${WORKSPACE}/out/${BUILD_TYPE} && md5sum * > MD5SUMS.txt)

# Build information
cat > ${WORKSPACE}/out/${BUILD_TYPE}/HEADER.textile << EOF

h4. Reference Platform - UEFI

Tianocore EDK2 UEFI build consumed by the Reference Platform Builds

Build Description:
* Build URL: "$BUILD_URL":$BUILD_URL
* UEFI Tools: "$UEFI_TOOLS_GIT_URL":$UEFI_TOOLS_GIT_URL
* UEFI Tools head: $UEFI_TOOLS_GIT_VERSION
* EDK2: "$EDK2_GIT_URL":$EDK2_GIT_URL
* EDK2 head: $EDK2_GIT_VERSION
* OpenPlatformPkg: "$OPEN_PLATFORM_PKG_GIT_URL":$OPEN_PLATFORM_PKG_GIT_URL
* OpenPlatformPkg branch: $OPEN_PLATFORM_PKG_GIT_BRANCH
* OpenPlatformPkg head: $OPEN_PLATFORM_PKG_GIT_VERSION
EOF

if [ "$BUILD_ATF" = "yes" ]; then
    cat >> ${WORKSPACE}/out/${BUILD_TYPE}/HEADER.textile << EOF
* ARM Trusted Firmware: "$ATF_GIT_URL":$ATF_GIT_URL
* ARM Trusted Firmware head: $ATF_GIT_VERSION
EOF
fi

if [ "$BUILD_TOS" = "yes" ]; then
    cat >> ${WORKSPACE}/out/${BUILD_TYPE}/HEADER.textile << EOF
* OP-TEE OS: "$OPTEE_OS_GIT_URL":$OPTEE_OS_GIT_URL
* OP-TEE OS head: $OPTEE_OS_GIT_VERSION
EOF
fi
