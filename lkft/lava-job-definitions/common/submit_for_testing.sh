#!/bin/bash

export PUB_DEST=android/lkft/${JOB_NAME}/${BUILD_NUMBER}
export DOWNLOAD_URL=http://snapshots.linaro.org/${PUB_DEST}
export KERNEL_COMMIT=${SRCREV_kernel}

export TEST_VTS_VERSION=$(echo ${TEST_VTS_URL} | awk -F"/" '{print$(NF-1)}')
export TEST_CTS_VERSION=$(echo ${TEST_CTS_URL} | awk -F"/" '{print$(NF-1)}')
[ -z "${TEST_METADATA_TOOLCHAIN}" ] && export TEST_METADATA_TOOLCHAIN="unknown"

if [ ! -z "${KERNEL_DESCRIBE}" ]; then
    export QA_BUILD_VERSION=${KERNEL_DESCRIBE}
else
    export QA_BUILD_VERSION=${KERNEL_COMMIT:0:12}
fi

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

config_url="https://android-git.linaro.org/android-build-configs.git/plain/lkft/${ANDROID_BUILD_CONFIG}?h=lkft"
wget ${config_url} -O ${ANDROID_BUILD_CONFIG}
source ${ANDROID_BUILD_CONFIG}

python configs/openembedded-lkft/submit_for_testing.py \
    --device-type ${TEST_DEVICE_TYPE} \
    --build-number ${BUILD_NUMBER} \
    --lava-server ${TEST_LAVA_SERVER} \
    --qa-server ${TEST_QA_SERVER} \
    --qa-server-team android-lkft \
    --env-suffix "_4.19" \
    --qa-server-project ${TEST_QA_SERVER_PROJECT} \
    --git-commit ${QA_BUILD_VERSION} \
    --testplan-path configs/lkft/lava-job-definitions/common \
    --test-plan template-boot.yaml template-vts-kernel.yaml template-cts.yaml \
    --quiet
