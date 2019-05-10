#!/bin/bash -ex

config_url="https://android-git.linaro.org/android-build-configs.git/plain/lkft/${ANDROID_BUILD_CONFIG}?h=lkft"
wget ${config_url} -O ${ANDROID_BUILD_CONFIG}
source ${ANDROID_BUILD_CONFIG}

function exit_with_msg(){
    echo "$@"
    exit
}

# environments must be defined in build config
[ -z "${TEST_DEVICE_TYPE}" ] && exit_with_msg "TEST_DEVICE_TYPE is required to be defined."
[ -z "${TEST_LAVA_SERVER}" ] && exit_with_msg "TEST_LAVA_SERVER is required to be defined."
[ -z "${TEST_QA_SERVER}" ] && exit_with_msg "TEST_QA_SERVER is required to be defined."
[ -z "${TEST_QA_SERVER_PROJECT}" ] && exit_with_msg "TEST_QA_SERVER_PROJECT is required to be defined."

[ -z "${ANDROID_VERSION}" ] && exit_with_msg "ANDROID_VERSION is required to be defined."
[ -z "${KERNEL_BRANCH}" ] && exit_with_msg "KERNEL_BRANCH is required to be defined."
[ -z "${KERNEL_REPO}" ] && exit_with_msg "KERNEL_REPO is required to be defined."
[ -z "${KERNEL_DESCRIBE}" ] && exit_with_msg "KERNEL_DESCRIBE is required to be defined."
[ -z "${TEST_METADATA_TOOLCHAIN}" ] && exit_with_msg "TEST_METADATA_TOOLCHAIN is required to be defined."
export ANDROID_VERSION KERNEL_BRANCH KERNEL_REPO TEST_METADATA_TOOLCHAIN
export TEST_VTS_VERSION=$(echo ${TEST_VTS_URL} | awk -F"/" '{print$(NF-1)}')
export TEST_CTS_VERSION=$(echo ${TEST_CTS_URL} | awk -F"/" '{print$(NF-1)}')

# environments set by the upstream trigger job
export KERNEL_DESCRIBE
export KERNEL_COMMIT=${SRCREV_kernel}
if [ ! -z "${KERNEL_DESCRIBE}" ]; then
    export QA_BUILD_VERSION=${KERNEL_DESCRIBE}
else
    export QA_BUILD_VERSION=${KERNEL_COMMIT:0:12}
fi

#environments exported by jenkins
#export BUILD_NUMBER JOB_NAME BUILD_URL

export PUB_DEST=android/lkft/${JOB_NAME}/${BUILD_NUMBER}
export DOWNLOAD_URL=http://snapshots.linaro.org/${PUB_DEST}

rm -rf configs && git clone --depth 1 http://git.linaro.org/ci/job/configs.git
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