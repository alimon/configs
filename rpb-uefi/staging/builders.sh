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

# Build setup
export EDK2_DIR=${WORKSPACE}/${BUILD_NUMBER}/edk2
export OPP_DIR=${WORKSPACE}/${BUILD_NUMBER}/OpenPlatformPkg
export ATF_DIR=${WORKSPACE}/${BUILD_NUMBER}/arm-trusted-firmware
export OPTEE_OS_DIR=${WORKSPACE}/${BUILD_NUMBER}/optee_os
export UEFI_TOOLS_DIR=${WORKSPACE}/${BUILD_NUMBER}/uefi-tools
export JENKINS_WORKSPACE=${WORKSPACE}

# WORKSPACE is used by uefi-build.sh
unset WORKSPACE

# NOTE: If using upstream ATF, we should set TOS_BIN to tee-pager.bin
if [ "${MX_PLATFORM}" = "hikey" ]; then
    sed -i "s|^TOS_BIN=tee.bin|TOS_BIN=tee-pager.bin|" ${UEFI_TOOLS_DIR}/platforms.config
fi

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

if [ "${MX_PLATFORM}" = "hikey" ]; then
    # HiKey requires an ATF fork for the recovery mode
    git clone --depth 1 https://github.com/96boards-hikey/atf-fastboot.git
    DEBUG=0; [ "${BUILD_TYPE}" = "debug" ] && DEBUG=1
    cd atf-fastboot; CROSS_COMPILE=aarch64-linux-gnu- make PLAT=${MX_PLATFORM} DEBUG=${DEBUG}; cd ..

    # Additional components for hikey, such as fastboot and l-loader
    cp -a ${EDK2_DIR}/Build/${IMAGE_DIR}/${MX_TYPE}_*/AARCH64/AndroidFastbootApp.efi out/${BUILD_TYPE}
    cd ${WORKSPACE}/${BUILD_NUMBER}
    git clone --depth 1 -b ${L_LOADER_GIT_BRANCH} ${L_LOADER_GIT_URL} l-loader
    cd l-loader
    ln -s ${EDK2_DIR}/Build/${IMAGE_DIR}/${MX_TYPE}_*/FV/bl1.bin
    ln -s ${EDK2_DIR}/Build/${IMAGE_DIR}/${MX_TYPE}_*/FV/bl2.bin
    ln -s ${WORKSPACE}/atf-fastboot/build/${MX_PLATFORM}/${BUILD_TYPE}/bl1.bin fastboot.bin
    make -f ${MX_PLATFORM}.mk recovery.bin
    make -f ${MX_PLATFORM}.mk l-loader.bin
    for ptable in aosp-4g aosp-8g linux-4g linux-8g; do
        PTABLE=${ptable} SECTOR_SIZE=512 bash -x generate_ptable.sh
        mv prm_ptable.img ptable-${ptable}.img
    done
    cp -a l-loader.bin recovery.bin ptable*.img ${WORKSPACE}/out/${BUILD_TYPE}
    wget https://raw.githubusercontent.com/96boards/burn-boot/master/hisi-idt.py -O ${WORKSPACE}/out/${BUILD_TYPE}/hisi-idt.py
    # Ship nvme.img with UEFI binaries for convenience
    dd if=/dev/zero of=${WORKSPACE}/out/${BUILD_TYPE}/nvme.img bs=128 count=1024

    # Ship files needed to build OP-TEE test suite
    tar -C ${OPTEE_OS_DIR}/out -acvf \
      ${WORKSPACE}/out/${BUILD_TYPE}/optee-arm-plat-hikey.tar.xz \
      arm-plat-hikey/export-ta_arm64 arm-plat-hikey/export-ta_arm32
fi
if [ "${MX_PLATFORM}" = "hikey960" ]; then
    # Additional components for hikey960, such as fastboot and l-loader
    cp -a ${EDK2_DIR}/Build/${IMAGE_DIR}/${MX_TYPE}_*/AARCH64/AndroidFastbootApp.efi out/${BUILD_TYPE}
    cd ${WORKSPACE}/${BUILD_NUMBER}
    git clone --depth 1 -b ${L_LOADER_GIT_BRANCH} ${L_LOADER_GIT_URL} l-loader
    cd l-loader
    ln -s ${EDK2_DIR}/Build/${IMAGE_DIR}/${MX_TYPE}_*/FV/bl1.bin
    ln -s ${EDK2_DIR}/Build/${IMAGE_DIR}/${MX_TYPE}_*/FV/bl2.bin
    ln -s ${EDK2_DIR}/Build/${IMAGE_DIR}/${MX_TYPE}_*/FV/fip.bin
    ln -s ${EDK2_DIR}/Build/${IMAGE_DIR}/${MX_TYPE}_*/FV/BL33_AP_UEFI.fd
    make -f ${MX_PLATFORM}.mk recovery.bin
    make -f ${MX_PLATFORM}.mk l-loader.bin
    PTABLE=aosp-32g SECTOR_SIZE=4096 SGDISK=./sgdisk bash -x generate_ptable.sh
    cp -a l-loader.bin recovery.bin prm_ptable.img ${WORKSPACE}/out/${BUILD_TYPE}
    cd ${WORKSPACE}/${BUILD_NUMBER}
    git clone --depth 1 https://github.com/96boards-hikey/tools-images-hikey960.git
    cd tools-images-hikey960
    cat > config << EOF
sec_usb_xloader.img 0x00020000
sec_uce_boot.img 0x6A908000
recovery.bin 0x1AC00000
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

if [ "$BUILD_ATF" = "yes" ]; then
    cat >> out/${BUILD_TYPE}/HEADER.textile << EOF
* ARM Trusted Firmware: "$ATF_GIT_URL":$ATF_GIT_URL
* ARM Trusted Firmware head: $ATF_GIT_VERSION
EOF
fi

if [ "$BUILD_TOS" = "yes" ]; then
    cat >> out/${BUILD_TYPE}/HEADER.textile << EOF
* OP-TEE OS: "$OPTEE_OS_GIT_URL":$OPTEE_OS_GIT_URL
* OP-TEE OS head: $OPTEE_OS_GIT_VERSION
EOF
fi
