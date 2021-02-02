#!/bin/bash -ex

export PATH=${HOME}/bin:${PATH}
export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8

#BUILD_CONFIG_FILENAME=aosp-master-x15
#KERNEL_REPO_URL=/data/android/aosp-mirror/kernel/omap.git
#OPT_MIRROR="-m /data/android/aosp-mirror/platform/manifest.git"
#BUILD_ROOT="/data/android/aosp/pure-master/test-x15-lkft"
#CLEAN_UP=false
#IN_JENKINS=false

BUILD_ROOT="${BUILD_ROOT:-/home/buildslave/srv/aosp-private}"
OPT_MIRROR="${OPT_MIRROR:-}"
CLEAN_UP=${CLEAN_UP:-true}

ANDROID_ROOT="${BUILD_ROOT}/build/aosp"
KERNEL_ROOT="${BUILD_ROOT}/build/kernel"
DIR_PUB_SRC="${BUILD_ROOT}/dist"
ANDROID_IMAGE_FILES="boot.img dtb.img dtbo.img super.img vendor.img product.img system.img system_ext.img vbmeta.img userdata.img ramdisk.img ramdisk-debug.img recovery.img cache.img"

# functions for clean the environemnt before repo sync and build
function prepare_environment(){
    if [ ! -d "${BUILD_ROOT}" ]; then
      sudo mkdir -p "${BUILD_ROOT}"
      sudo chmod 777 "${BUILD_ROOT}"
    fi
    cd "${BUILD_ROOT}"

    # clean files under ${DIR_SRV_AOSP_MASTER}
    rm -rf "${ANDROID_ROOT}"
}

###############################################################
# Build Android userspace images
# All operations following should be done under ${ANDROID_ROOT}
###############################################################
function build_android(){
    mkdir -p ${ANDROID_ROOT} && cd ${ANDROID_ROOT}
    rm -fr ${DIR_PUB_SRC} && mkdir -p ${DIR_PUB_SRC}
    rm -fr ${ANDROID_ROOT}/out/pinned-manifest

    rm -fr android-build-configs linaro-build.sh
    wget -c https://android-git.linaro.org/android-build-configs.git/plain/linaro-build.sh -O linaro-build.sh
    chmod +x linaro-build.sh
    if [ -n "${ANDROID_BUILD_CONFIG}" ]; then
        bash -x ./linaro-build.sh -c "${ANDROID_BUILD_CONFIG}"
        # ${ANDROID_BUILD_CONFIG} will be repo synced after build
        source android-build-configs/${ANDROID_BUILD_CONFIG}
        export TARGET_PRODUCT
    elif [ -n "${TARGET_PRODUCT}" ]; then
        local opt_manfest_branch="-b master"
        local opt_maniefst_url="https://android.googlesource.com/platform/manifest"
        [ -n "${MANIFEST_BRANCH}" ] && opt_manfest_branch="-b ${MANIFEST_BRANCH}"
        [ -n "${MANIFEST_URL}" ] && opt_maniefst_url="-m ${MANIFEST_URL}"
        bash -x ./linaro-build.sh -tp "${TARGET_PRODUCT}" ${opt_maniefst_url} ${opt_manfest_branch}
    fi
    DIR_PUB_SRC_PRODUCT="${ANDROID_ROOT}/out/target/product/${TARGET_PRODUCT}"

    mkdir -p ${DIR_PUB_SRC}
    cp -a ${ANDROID_ROOT}/out/pinned-manifest/*-pinned-manifest.xml ${DIR_PUB_SRC}
    wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/lkft/common/build-info/member.txt -O ${DIR_PUB_SRC}/BUILD-INFO.txt

    for f in ${ANDROID_IMAGE_FILES}; do
        if [ ! -f ${DIR_PUB_SRC_PRODUCT}/${f} ]; then
            continue
        fi

        mv -vf ${DIR_PUB_SRC_PRODUCT}/${f} ${DIR_PUB_SRC}/${f}

        if [ "Xramdisk.img" = "X${f}" ] || [ "Xramdisk-debug.img" = "X${f}" ]; then
            continue
        fi
        xz -T 0 ${DIR_PUB_SRC}/${f}
    done

    if [ -f ${DIR_PUB_SRC_PRODUCT}/build_fingerprint.txt ]; then
        cp -vf ${DIR_PUB_SRC_PRODUCT}/build_fingerprint.txt ${DIR_PUB_SRC}/
    fi

    if [ -n "${ANDROID_BUILD_CONFIG}" ]; then
        cp -vf android-build-configs/${ANDROID_BUILD_CONFIG} ${DIR_PUB_SRC}/${ANDROID_BUILD_CONFIG}.txt
    else
        ANDROID_BUILD_CONFIG="build-config"
        rm -f ${DIR_PUB_SRC}/${ANDROID_BUILD_CONFIG}.txt
        [ -n "${TARGET_PRODUCT}" ] && echo "TARGET_PRODUCT=${TARGET_PRODUCT}" >>${DIR_PUB_SRC}/${ANDROID_BUILD_CONFIG}.txt
        [ -n "${MANIFEST_BRANCH}" ] && echo "MANIFEST_BRANCH=${MANIFEST_BRANCH}" >>${DIR_PUB_SRC}/${ANDROID_BUILD_CONFIG}.txt
        [ -n "${MANIFEST_URL}" ] && echo "MANIFEST_URL=${MANIFEST_URL}" >>${DIR_PUB_SRC}/${ANDROID_BUILD_CONFIG}.txt
    fi
}

# clean workspace to save space
function clean_workspace(){
    rm -fr ${ANDROID_ROOT}
}

# export parameters for publish/job submission steps
function export_parameters(){

    # beagle_x15 could not used as part of the url for snapshot site
    if [ "X${TARGET_PRODUCT}" = "Xbeagle_x15" ]; then
        PUB_DEST_TARGET=x15
    else
        PUB_DEST_TARGET=${TARGET_PRODUCT}
    fi

    # Publish parameters
    cp -a ${DIR_PUB_SRC}/*-pinned-manifest.xml ${WORKSPACE}/ || true
    echo "PUB_DEST=android/lkft/protected/aosp/${PUB_DEST_TARGET}/${BUILD_NUMBER}" > ${WORKSPACE}/publish_parameters
    echo "PUB_SRC=${DIR_PUB_SRC}" >> ${WORKSPACE}/publish_parameters
    echo "PUB_EXTRA_INC=^[^/]+\.(txt|img|xz|dtb|dtbo|zip)$|MLO|vmlinux|System.map" >> ${WORKSPACE}/publish_parameters
}

function main(){
    prepare_environment
    build_android

    if ${IN_JENKINS} && [ -n "${WORKSPACE}" ]; then
        clean_workspace
        export_parameters
    fi
}

main "$@"
