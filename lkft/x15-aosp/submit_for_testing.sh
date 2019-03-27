#!/bin/bash

export DEVICE_TYPE=x15
export LAVA_SERVER=https://lkft.validation.linaro.org/RPC2/
export DOWNLOAD_URL=http://snapshots.linaro.org/${PUB_DEST}
export KERNEL_COMMIT=${SRCREV_kernel}
export VTS_VERSION=$(echo $VTS_URL | awk -F"/" '{print$(NF-1)}')
export CTS_VERSION=$(echo $CTS_URL | awk -F"/" '{print$(NF-1)}')
[ -z "${TOOLCHAIN}" ] && export TOOLCHAIN="unknown"
[ -z "${BOOTARGS}" ] && export BOOTARGS="androidboot.serialno=\${serial#} console=ttyS2,115200 androidboot.console=ttyS2 androidboot.hardware=beagle_x15board"

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

python configs/openembedded-lkft/submit_for_testing.py \
    --device-type ${DEVICE_TYPE} \
    --build-number ${BUILD_NUMBER} \
    --lava-server ${LAVA_SERVER} \
    --qa-server ${QA_SERVER} \
    --qa-server-team android-lkft \
    --qa-server-project ${QA_SERVER_PROJECT} \
    --git-commit ${QA_BUILD_VERSION} \
    --testplan-path configs/lkft/lava-job-definitions/x15 \
    --test-plan template-boot.yaml template-vts-kernel.yaml template-cts.yaml \
    --quiet

python configs/openembedded-lkft/submit_for_testing.py \
    --device-type ${DEVICE_TYPE} \
    --build-number ${BUILD_NUMBER} \
    --lava-server ${LAVA_SERVER} \
    --qa-server ${QA_SERVER} \
    --qa-server-team staging-lkft \
    --qa-server-project ${QA_SERVER_PROJECT} \
    --git-commit ${QA_BUILD_VERSION} \
    --testplan-path configs/lkft/lava-job-definitions/x15 \
    --test-plan template-vts-staging-kernel.yaml \
    --quiet
