#!/bin/bash -ex

export PATH=${HOME}/bin:${PATH}
export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8

#BUILD_CONFIG_FILENAME=aosp-master-x15
#KERNEL_REPO_URL=/data/android/aosp-mirror/kernel/omap.git
#OPT_MIRROR="-m /data/android/aosp-mirror/platform/manifest.git"
#DIR_SRV_AOSP_MASTER="/data/android/aosp/pure-master/test-x15-lkft"
#CLEAN_UP=false
#IN_JENKINS=false

DIR_SRV_AOSP_MASTER="${DIR_SRV_AOSP_MASTER:-/home/buildslave/srv/aosp-master}"
BUILD_CONFIG_FILENAME=${BUILD_CONFIG_FILENAME:-${JOB_NAME#android-*}}
KERNEL_REPO_URL=${KERNEL_REPO_URL:-https://android.googlesource.com/kernel/omap}
OPT_MIRROR="${OPT_MIRROR:-}"
# https://developer.arm.com/tools-and-software/open-source-software/developer-tools/gnu-toolchain/gnu-a/downloads/8-3-2019-03
TOOLCHAIN_NAME="${TOOLCHAIN_NAME:-gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf}"
TOOLCHAIN_URL="${TOOLCHAIN_URL:-https://developer.arm.com/-/media/Files/downloads/gnu-a/8.3-2019.03/binrel/${TOOLCHAIN_NAME}.tar.xz}"
CROSS_COMPILE=${CROSS_COMPILE:-${TOOLCHAIN_NAME}/bin/arm-linux-gnueabihf-}
CLEAN_UP=${CLEAN_UP:-true}

ANDROID_ROOT="${DIR_SRV_AOSP_MASTER}/build"
DIR_PUB_SRC="${ANDROID_ROOT}/out/dist"
DIR_PUB_SRC_PRODUCT="${ANDROID_ROOT}/out/target/product/beagle_x15"
ANDROID_IMAGE_FILES="boot.img dtb.img dtbo.img super.img vbmeta.img userdata.img ramdisk.img ramdisk-debug.img recovery.img"

# functions for clean the environemnt before repo sync and build
function prepare_environment(){
    if [ ! -d "${DIR_SRV_AOSP_MASTER}" ]; then
      sudo mkdir -p "${DIR_SRV_AOSP_MASTER}"
      sudo chmod 777 "${DIR_SRV_AOSP_MASTER}"
    fi
    cd "${DIR_SRV_AOSP_MASTER}"

    # clean files under ${DIR_SRV_AOSP_MASTER}
    rm -rf .repo/manifests* .repo/local_manifests build-tools jenkins-tools

    # clean the build directory as it is used accross multiple builds
    # by removing all files except the .repo directory
    if ${CLEAN_UP}; then
        rm -fr ${DIR_SRV_AOSP_MASTER}/.repo-backup
        if [ -d "${ANDROID_ROOT}/.repo" ]; then
            mv -f ${ANDROID_ROOT}/.repo ${DIR_SRV_AOSP_MASTER}/.repo-backup
        fi
        rm -fr ${ANDROID_ROOT}/ && mkdir -p ${ANDROID_ROOT}
        if [ -d "${DIR_SRV_AOSP_MASTER}/.repo-backup" ]; then
            mv -f ${DIR_SRV_AOSP_MASTER}/.repo-backup ${ANDROID_ROOT}/.repo
        fi
    fi
}

###############################################################
# Build Android for X15
# All operations following should be done under ${ANDROID_ROOT}
###############################################################
function build_android(){
    cd ${ANDROID_ROOT}
    rm -fr ${DIR_PUB_SRC} && mkdir -p ${DIR_PUB_SRC}
    rm -fr ${ANDROID_ROOT}/out/pinned-manifest

    rm -fr android-build-configs
    git clone --depth 1 http://android-git.linaro.org/git/android-build-configs.git android-build-configs
    ./android-build-configs/linaro-build.sh -c ${BUILD_CONFIG_FILENAME} ${OPT_MIRROR}

    mkdir -p ${DIR_PUB_SRC}
    cp -a ${ANDROID_ROOT}/out/pinned-manifest/*-pinned-manifest.xml ${DIR_PUB_SRC}
    wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/hikey/build-info/aosp-master-template.txt -O ${DIR_PUB_SRC}/BUILD-INFO.txt

    for f in ${ANDROID_IMAGE_FILES}; do
        mv -vf ${DIR_PUB_SRC_PRODUCT}/${f} ${DIR_PUB_SRC}/aosp-${f}
        xz -T 0 ${DIR_PUB_SRC}/aosp-${f}
    done
}

#######################################
###### compile x15 4.19 kernel
#######################################
function build_kernel(){
    cd ${ANDROID_ROOT}

    local kernel_ver="${1}"
    if [ -z "${kernel_ver}" ]; then
        return
    fi

    # git clone omap kernel
    X15_KERNEL_DIR=${ANDROID_ROOT}/kernel/omap/x15
    if ${CLEAN_UP}; then
        rm -fr ${X15_KERNEL_DIR} && mkdir -p ${X15_KERNEL_DIR}
        git clone ${KERNEL_REPO_URL} ${X15_KERNEL_DIR}
    fi

    cd ${X15_KERNEL_DIR}
    git checkout android-beagle-x15-${kernel_ver} && git clean -fdx && git pull
    local ver_name=$(echo ${kernel_ver}|tr '.' '_')
    local kernel_describe=$(git rev-parse --short HEAD)
    local kernel_makeversion=$(make kernelversion)
    export KERNEL_DESCRIBE_X15_${ver_name}=${kernel_describe}
    export KERNEL_VERSION_X15_${ver_name}=${kernel_makeversion}

    # change to ${ANDROID_ROOT} to make sure in the right directory
    cd ${ANDROID_ROOT}
    KERNEL_BUILD_OUT=${DIR_PUB_SRC_PRODUCT}/obj/kernel-${kernel_ver}

    if ${CLEAN_UP}; then
        make \
            CROSS_COMPILE=${ANDROID_ROOT}/${CROSS_COMPILE} \
            -C ${X15_KERNEL_DIR} \
            O=${KERNEL_BUILD_OUT} \
            mrproper
    fi
    make -j1 \
        ARCH=arm \
        CROSS_COMPILE=${ANDROID_ROOT}/${CROSS_COMPILE} \
        -C ${X15_KERNEL_DIR} \
        O=${KERNEL_BUILD_OUT} \
        ti_sdk_am57x_android_release_defconfig
    make -j$(nproc) \
        ARCH=arm \
        CROSS_COMPILE=${ANDROID_ROOT}/${CROSS_COMPILE} \
        -C ${X15_KERNEL_DIR} \
        O=${KERNEL_BUILD_OUT} \
        zImage dtbs modules

    # regenerate the android images files
    KERNELDIR=${KERNEL_BUILD_OUT} ./android-build-configs/linaro-build.sh -tp beagle_x15 -ss

    for f in ${ANDROID_IMAGE_FILES}; do
        mv -vf ${DIR_PUB_SRC_PRODUCT}/${f} ${DIR_PUB_SRC}/${kernel_ver}-${f}
        xz -T 0 ${DIR_PUB_SRC}/${kernel_ver}-${f}
    done
}

#######################################
##### compile u-boot files
#######################################
function build_uboot(){
    cd ${ANDROID_ROOT}

    local UBOOT_DIR=${ANDROID_ROOT}/external/u-boot
    local UBOOT_OUT_DIR=${DIR_PUB_SRC_PRODUCT}/obj/u-boot

    if ${CLEAN_UP}; then
        rm -fr ${UBOOT_OUT_DIR} && mkdir -p ${UBOOT_OUT_DIR}
    fi

    make -j1 \
        -C ${UBOOT_DIR} \
        O=${UBOOT_OUT_DIR} \
        ARCH=arm \
        CROSS_COMPILE=${ANDROID_ROOT}/${CROSS_COMPILE} \
        am57xx_evm_defconfig
    make -j$(nproc) \
        -C ${UBOOT_DIR} \
        O=${UBOOT_OUT_DIR} \
        ARCH=arm \
        CROSS_COMPILE=${ANDROID_ROOT}/${CROSS_COMPILE}

    cp -vf ${UBOOT_OUT_DIR}/u-boot.img ${DIR_PUB_SRC}/u-boot.img
    cp -vf ${UBOOT_OUT_DIR}/MLO ${DIR_PUB_SRC}/MLO
}

# clean workspace to save space
function clean_workspace(){
    cd ${ANDROID_ROOT}
    # Delete sources after build to save space
    rm -rf art/ dalvik/ kernel/ bionic/ developers/ libcore/ sdk/ bootable/ development/
    rm -fr libnativehelper/ system/ build/ device/ test/ build-info/ docs/ packages/
    rm -fr toolchain/ .ccache/ external/ pdk/ tools/ compatibility/ frameworks/
    rm -fr platform_testing/ vendor/ cts/ hardware/ prebuilts/
    rm -fr ${X15_KERNEL_DIR}
}

# export parameters for publish/job submission steps
function export_parameters(){
    # Publish parameters
    cp -a ${DIR_PUB_SRC}/*-pinned-manifest.xml ${WORKSPACE}/ || true
    echo "PUB_DEST=android/lkft/lkft-aosp-master-x15/${BUILD_NUMBER}" > ${WORKSPACE}/publish_parameters
    echo "PUB_SRC=${DIR_PUB_SRC}" >> ${WORKSPACE}/publish_parameters
    echo "PUB_EXTRA_INC=^[^/]+\.(xz|dtb|dtbo|zip)$|MLO|vmlinux|System.map" >> ${WORKSPACE}/publish_parameters

    echo "KERNEL_DESCRIBE_X15_4_19=${KERNEL_DESCRIBE_X15_4_19}" >> ${WORKSPACE}/publish_parameters
    echo "KERNEL_VERSION_X15_4_19=${KERNEL_VERSION_X15_4_19}" >> ${WORKSPACE}/publish_parameters
}

function main(){
    prepare_environment
    build_android

    # download and decompress toolchain files
    wget -c ${TOOLCHAIN_URL} -O ${TOOLCHAIN_NAME}.tar.xz
    tar -xvf ${TOOLCHAIN_NAME}.tar.xz

    build_kernel 4.19
    build_uboot

    if ${IN_JENKINS} && [ -n "${WORKSPACE}" ]; then
        clean_workspace
        export_parameters
    fi
}

main "$@"
