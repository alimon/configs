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

# Use pre-installed linaro toolchain (GCC 5.3)
export PATH="${HOME}/srv/toolchain/arm-tc-16.02/bin:${HOME}/srv/toolchain/arm64-tc-16.02/bin:$PATH"

# Common git repositories to fetch
UEFI_TOOLS_GIT_URL=https://git.linaro.org/uefi/uefi-tools.git
UEFI_TOOLS_GIT_BRANCH=master
#EDK2_GIT_URL=https://github.com/tianocore/edk2.git
EDK2_GIT_URL=https://git.linaro.org/uefi/linaro-edk2.git
EDK2_GIT_VERSION=$EDK2_VERSION
ATF_GIT_URL=https://github.com/ARM-software/arm-trusted-firmware.git
ATF_GIT_VERSION=$ATF_VERSION
## Temporarily switch to a dev tree/branch
OPEN_PLATFORM_PKG_GIT_URL=https://git.linaro.org/uefi/OpenPlatformPkg.git
OPEN_PLATFORM_PKG_GIT_BRANCH=master
OPTEE_OS_GIT_URL=https://github.com/OP-TEE/optee_os.git
OPTEE_GIT_VERSION=$OPTEE_VERSION

# So we can easily identify the build number via build path
mkdir ${BUILD_NUMBER}; cd ${BUILD_NUMBER}

# Per board repositories overrides
if [ "${MX_PLATFORM}" == "hikey" ]; then
    EDK2_GIT_URL=https://github.com/96boards-hikey/edk2.git
    EDK2_GIT_VERSION="origin/hikey-aosp"
    ATF_GIT_URL=https://github.com/96boards-hikey/arm-trusted-firmware.git
    ATF_GIT_VERSION="origin/hikey"
    OPEN_PLATFORM_PKG_GIT_URL=https://github.com/96boards-hikey/OpenPlatformPkg.git
    OPEN_PLATFORM_PKG_GIT_BRANCH=hikey-aosp
fi
if [ "${MX_PLATFORM}" == "hikey960" ]; then
    EDK2_GIT_URL=https://github.com/96boards-hikey/edk2.git
    EDK2_GIT_VERSION="origin/testing/hikey960_v2.5"
    ATF_GIT_URL=https://github.com/96boards-hikey/arm-trusted-firmware.git
    ATF_GIT_VERSION="origin/testing/hikey960_v1.1"
    OPEN_PLATFORM_PKG_GIT_URL=https://github.com/96boards-hikey/OpenPlatformPkg.git
    OPEN_PLATFORM_PKG_GIT_BRANCH="testing/hikey960_v1.3.4"
    L_LOADER_GIT_URL=https://github.com/96boards-hikey/l-loader.git
    L_LOADER_GIT_BRANCH="testing/hikey960_v1.2"
fi

# Force cap GCC build profile to GCC49, still preferred by upstream
TOOLCHAIN=GCC49
export AARCH64_TOOLCHAIN=GCC49

# Clone the repos
git clone -b $UEFI_TOOLS_GIT_BRANCH $UEFI_TOOLS_GIT_URL uefi-tools
cd uefi-tools; UEFI_TOOLS_GIT_VERSION=`git log --format="%H" -1`; cd ..

git clone $EDK2_GIT_URL edk2
cd edk2; git checkout -b stable-baseline $EDK2_GIT_VERSION
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

# Build setup
export EDK2_DIR=${WORKSPACE}/${BUILD_NUMBER}/edk2
export OPP_DIR=${WORKSPACE}/${BUILD_NUMBER}/OpenPlatformPkg
export ATF_DIR=${WORKSPACE}/${BUILD_NUMBER}/arm-trusted-firmware
export OPTEE_OS_DIR=${WORKSPACE}/${BUILD_NUMBER}/optee_os
export UEFI_TOOLS_DIR=${WORKSPACE}/${BUILD_NUMBER}/uefi-tools
export JENKINS_WORKSPACE=${WORKSPACE}

# WORKSPACE is used by uefi-build.sh
unset WORKSPACE

# Build UEFI for the desired platform, with the specified build type
cd ${EDK2_DIR}
bash -x ${UEFI_TOOLS_DIR}/uefi-build.sh -T ${TOOLCHAIN} -b ${MX_TYPE} -a ${ATF_DIR} -s ${OPTEE_OS_DIR} ${MX_PLATFORM}

unset WORKSPACE
export WORKSPACE=${JENKINS_WORKSPACE}

# Find out the artifacts and image dir so we can publish the correct output files
IMAGES=`$UEFI_TOOLS_DIR/parse-platforms.py -c $UEFI_TOOLS_DIR/platforms.config -p ${MX_PLATFORM} images`
IMAGE_DIR=`$UEFI_TOOLS_DIR/parse-platforms.py -c $UEFI_TOOLS_DIR/platforms.config -p ${MX_PLATFORM} -o UEFI_IMAGE_DIR get`
BUILD_ATF=`$UEFI_TOOLS_DIR/parse-platforms.py -c $UEFI_TOOLS_DIR/platforms.config -p ${MX_PLATFORM} -o BUILD_ATF get`
BUILD_TOS=`$UEFI_TOOLS_DIR/parse-platforms.py -c $UEFI_TOOLS_DIR/platforms.config -p ${MX_PLATFORM} -o BUILD_TOS get`

cd ${WORKSPACE}
mkdir -p out/${BUILD_TYPE}
for image in ${IMAGES}; do
    cp -a ${EDK2_DIR}/Build/${IMAGE_DIR}/${MX_TYPE}_*/FV/${image} out/${BUILD_TYPE}/
done

cat > out/${BUILD_TYPE}/BUILD-INFO.txt << EOF
Format-Version: 0.5

Files-Pattern: *
License-Type: open
EOF

if [ "${MX_PLATFORM}" == "hikey" ]; then
    # Additional components for hikey, such as fastboot and l-loader
    cp -a ${EDK2_DIR}/Build/${IMAGE_DIR}/${MX_TYPE}_*/AARCH64/AndroidFastbootApp.efi out/${BUILD_TYPE}
    cd ${WORKSPACE}/${BUILD_NUMBER}
    git clone --depth 1 https://github.com/96boards-hikey/l-loader.git
    cd l-loader
    ln -s ${WORKSPACE}/out/${BUILD_TYPE}/bl1.bin
    make
    cp -a l-loader.bin ptable*.img ${WORKSPACE}/out/${BUILD_TYPE}
    wget https://raw.githubusercontent.com/96boards/burn-boot/master/hisi-idt.py -O ${WORKSPACE}/out/${BUILD_TYPE}/hisi-idt.py
    # Ship nvme.img with UEFI binaries for convenience
    dd if=/dev/zero of=${WORKSPACE}/out/${BUILD_TYPE}/nvme.img bs=128 count=1024

    # Ship files needed to build OP-TEE test suite
    tar -C ${OPTEE_OS_DIR}/out -acvf \
      ${WORKSPACE}/out/${BUILD_TYPE}/optee-arm-plat-hikey.tar.xz \
      arm-plat-hikey/export-ta_arm64 arm-plat-hikey/export-ta_arm32
fi
if [ "${MX_PLATFORM}" == "hikey960" ]; then
    # Additional components for hikey960, such as fastboot and l-loader
    cp -a ${EDK2_DIR}/Build/${IMAGE_DIR}/${MX_TYPE}_*/AARCH64/AndroidFastbootApp.efi out/${BUILD_TYPE}
    cd ${WORKSPACE}/${BUILD_NUMBER}
    git clone --depth 1 -b ${L_LOADER_GIT_BRANCH} ${L_LOADER_GIT_URL} l-loader
    cd l-loader
    ln -s ${WORKSPACE}/out/${BUILD_TYPE}/bl1.bin
    ln -s ${WORKSPACE}/out/${BUILD_TYPE}/fip.bin
    ln -s ${EDK2_DIR}/Build/${IMAGE_DIR}/${MX_TYPE}_*/FV/BL33_AP_UEFI.fd
    PTABLE=aosp-32g SECTOR_SIZE=4096 SGDISK=./sgdisk bash -x generate_ptable.sh
    python gen_loader_hikey960.py -o l-loader.bin --img_bl1=bl1.bin --img_ns_bl1u=BL33_AP_UEFI.fd
    cp -a l-loader.bin prm_ptable.img ${WORKSPACE}/out/${BUILD_TYPE}
    cd ${WORKSPACE}/${BUILD_NUMBER}
    git clone --depth 1 https://github.com/96boards-hikey/tools-images-hikey960.git
    cd tools-images-hikey960
    cat > config << EOF
sec_usb_xloader.img 0x00020000
sec_uce_boot.img 0x6A908000
l-loader.bin 0x1AC00000
EOF
    cp -a config hikey_idt sec_uce_boot.img sec_usb_xloader.img sec_xloader.img ${WORKSPACE}/out/${BUILD_TYPE}/
fi
cd ${WORKSPACE}

# Create MD5SUMS file
(cd out/${BUILD_TYPE} && md5sum * > MD5SUMS.txt)

# Build information
cat > out/${BUILD_TYPE}/HEADER.textile << EOF

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

if [ "$BUILD_ATF" == "yes" ]; then
    cat >> out/${BUILD_TYPE}/HEADER.textile << EOF
* ARM Trusted Firmware: "$ATF_GIT_URL":$ATF_GIT_URL
* ARM Trusted Firmware head: $ATF_GIT_VERSION
EOF
fi

if [ "$BUILD_TOS" == "yes" ]; then
    cat >> out/${BUILD_TYPE}/HEADER.textile << EOF
* OP-TEE OS: "$OPTEE_OS_GIT_URL":$OPTEE_OS_GIT_URL
* OP-TEE OS head: $OPTEE_OS_GIT_VERSION
EOF
fi
