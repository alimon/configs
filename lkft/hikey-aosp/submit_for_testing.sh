#!/bin/bash

export DEVICE_TYPE=hi6220-hikey
export LAVA_SERVER=https://lkft.validation.linaro.org/RPC2/
export PUB_DEST=android/lkft/${JOB_NAME}/${BUILD_NUMBER}
export DOWNLOAD_URL=http://snapshots.linaro.org/${PUB_DEST}
export KERNEL_COMMIT=${SRCREV_kernel}
if [ -z "${ANDROID_VERSION}" ]; then
    export ANDROID_VERSION=$(echo $REFERENCE_BUILD_URL | awk -F"/" '{print$(NF-1)}')
else
    export ANDROID_VERSION
fi
export VTS_VERSION=$(echo $VTS_URL | awk -F"/" '{print$(NF-1)}')
export CTS_VERSION=$(echo $CTS_URL | awk -F"/" '{print$(NF-1)}')
[ -z "${TOOLCHAIN}" ] && export TOOLCHAIN="unknown"

if [ ! -z "${KERNEL_DESCRIBE}" ]; then
    export QA_BUILD_VERSION=${KERNEL_DESCRIBE}
else
    export QA_BUILD_VERSION=${KERNEL_COMMIT:0:12}
fi

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

if curl --output /dev/null --silent --head --fail "${REFERENCE_BUILD_URL}/vendor.img.xz"; then
    echo "This reference build comes with a vendor partition"
else
    echo "No vendor partition, so flashing cache partition from the job instead"
    sed -i "s|vendor.img.xz|cache.img.xz|g" configs/lkft/lava-job-definitions/${DEVICE_TYPE}/*.yaml
fi

if echo ${KERNEL_BRANCH} | grep "4.4"; then
   sed -i "s|vendor.img.xz|vendor-4.4.img.xz|g" configs/lkft/lava-job-definitions/${DEVICE_TYPE}/*.yaml
fi

if curl --output /dev/null --silent --head --fail "${REFERENCE_BUILD_URL}/SHA256SUMS.txt"; then
    curl  -o reference_build_url_SHA256SUMS.txt "${REFERENCE_BUILD_URL}/SHA256SUMS.txt"
    sed -i '/BOOT_IMG_SHA256SUM/d' reference_build_url_SHA256SUMS.txt
    source reference_build_url_SHA256SUMS.txt
    if ! test -z "${SYSTEM_IMG_SHA256SUM}"; then
        export SYSTEM_IMG_SHA256SUM
    else
        sed -i '/SYSTEM_IMG_SHA256SUM/d' configs/lkft/lava-job-definitions/${DEVICE_TYPE}/*.yaml
    if ! test -z "${VENDOR_IMG_SHA256SUM}"; then
        export VENDOR_IMG_SHA256SUM
    else
        sed -i '/VENDOR_IMG_SHA256SUM/d' configs/lkft/lava-job-definitions/${DEVICE_TYPE}/*.yaml
    fi
    if ! test -z "${USERDATA_IMG_SHA256SUM}"; then
        export USERDATA_IMG_SHA256SUM
    else
        sed -i '/USERDATA_IMG_SHA256SUM/d' configs/lkft/lava-job-definitions/${DEVICE_TYPE}/*.yaml
    fi
fi

python configs/openembedded-lkft/submit_for_testing.py \
    --device-type ${DEVICE_TYPE} \
    --build-number ${BUILD_NUMBER} \
    --lava-server ${LAVA_SERVER} \
    --qa-server ${QA_SERVER} \
    --qa-server-team android-lkft \
    --qa-server-project ${QA_SERVER_PROJECT} \
    --git-commit ${QA_BUILD_VERSION} \
    --template-path configs/lkft/lava-job-definitions \
    --template-names template-boot.yaml template-vts-kernel.yaml template-cts.yaml \
    --quiet

python configs/openembedded-lkft/submit_for_testing.py \
    --device-type ${DEVICE_TYPE} \
    --build-number ${BUILD_NUMBER} \
    --lava-server ${LAVA_SERVER} \
    --qa-server ${QA_SERVER} \
    --qa-server-team staging-lkft \
    --qa-server-project ${QA_SERVER_PROJECT}-vts-staging \
    --git-commit ${QA_BUILD_VERSION} \
    --template-path configs/lkft/lava-job-definitions \
    --template-names template-vts-staging-kernel.yaml \
    --quiet
