#!/bin/bash

export DEVICE_TYPE=hi6220-hikey
export LAVA_SERVER=https://lkft.validation.linaro.org/RPC2/
export PUB_DEST=android/lkft/${JOB_NAME}/${BUILD_NUMBER}
export DOWNLOAD_URL=http://snapshots.linaro.org/${PUB_DEST}
export KERNEL_COMMIT=${SRCREV_kernel}
export ANDROID_VERSION=$(echo $REFERENCE_BUILD_URL | awk -F"/" '{print$(NF-1)}')
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
    sed -i "s|vendor|cache|g" configs/lkft/lava-job-definitions/${DEVICE_TYPE}/*.yaml
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
    --template-names template-boot.yaml template-vts-kernel-part1.yaml template-vts-kernel-part2.yaml template-vts-kernel-part3.yaml template-vts-kernel-part4.yaml template-cts-armeabi-v7a.yaml template-cts-arm64-v8a.yaml \
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
