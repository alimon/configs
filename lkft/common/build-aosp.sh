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
KERNEL_REPO_URL=${KERNEL_REPO_URL:-https://android.googlesource.com/kernel/omap}
OPT_MIRROR="${OPT_MIRROR:-}"
CLEAN_UP=${CLEAN_UP:-true}

ANDROID_ROOT="${DIR_SRV_AOSP_MASTER}/build"
DIR_PUB_SRC="${ANDROID_ROOT}/out/dist"
ANDROID_IMAGE_FILES="boot.img dtb.img dtbo.img super.img vendor.img product.img system.img system_ext.img vbmeta.img userdata.img ramdisk.img ramdisk-debug.img recovery.img cache.img"
ANDROID_IMAGE_FILES="${ANDROID_IMAGE_FILES} vendor_boot-debug.img vendor_boot.img"

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

    rm -fr android-build-configs linaro-build.sh
    wget -c https://android-git.linaro.org/android-build-configs.git/plain/linaro-build.sh -O linaro-build.sh
    chmod +x linaro-build.sh
    if [ -n "${ANDROID_BUILD_CONFIG}" ]; then
        bash -x ./linaro-build.sh -c "${ANDROID_BUILD_CONFIG}"
        # ${ANDROID_BUILD_CONFIG} will be repo synced after build
        source android-build-configs/${ANDROID_BUILD_CONFIG}
        export TARGET_PRODUCT
    elif [ -n "${TARGET_PRODUCT}" ]; then
        local manfest_branch="master"
        [ -n "${MANIFEST_BRANCH}" ] && manfest_branch=${MANIFEST_BRANCH}
        bash -x ./linaro-build.sh -tp "${TARGET_PRODUCT}" -b "${manfest_branch}"
    fi
    DIR_PUB_SRC_PRODUCT="${ANDROID_ROOT}/out/target/product/${TARGET_PRODUCT}"

    mkdir -p ${DIR_PUB_SRC}
    cp -a ${ANDROID_ROOT}/out/pinned-manifest/*-pinned-manifest.xml ${DIR_PUB_SRC}
    wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/hikey/build-info/aosp-master-template.txt -O ${DIR_PUB_SRC}/BUILD-INFO.txt

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
    fi
}

# clean workspace to save space
function clean_workspace(){
    cd ${ANDROID_ROOT}
    # Delete sources after build to save space
    rm -rf art/ dalvik/ kernel/ bionic/ developers/ libcore/ sdk/ bootable/ development/
    rm -fr libnativehelper/ system/ build/ device/ test/ build-info/ docs/ packages/
    rm -fr toolchain/ .ccache/ external/ pdk/ tools/ compatibility/ frameworks/
    rm -fr platform_testing/ vendor/ cts/ hardware/ prebuilts/
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
    echo "PUB_DEST=android/lkft/${PUB_DEST_TARGET}/${BUILD_NUMBER}" > ${WORKSPACE}/publish_parameters
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
