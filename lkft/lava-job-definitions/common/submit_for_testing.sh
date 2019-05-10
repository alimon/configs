#!/bin/bash -ex

F_ABS_PATH=$(readlink -e $0)

config_url="https://android-git.linaro.org/android-build-configs.git/plain/lkft/${ANDROID_BUILD_CONFIG}?h=lkft"
wget ${config_url} -O ${ANDROID_BUILD_CONFIG}
source ${ANDROID_BUILD_CONFIG}

function exit_with_msg(){
    echo "$@"
    exit
}

# environments must be defined in build config
# following environments no need to be exported as they only used for here.
[ -z "${TEST_DEVICE_TYPE}" ] && exit_with_msg "TEST_DEVICE_TYPE is required to be defined."
[ -z "${TEST_LAVA_SERVER}" ] && exit_with_msg "TEST_LAVA_SERVER is required to be defined."
[ -z "${TEST_QA_SERVER}" ] && exit_with_msg "TEST_QA_SERVER is required to be defined."
[ -z "${TEST_QA_SERVER_PROJECT}" ] && exit_with_msg "TEST_QA_SERVER_PROJECT is required to be defined."

# following environments must be exported as they will be used in the job templates.
[ -z "${ANDROID_VERSION}" ] && exit_with_msg "ANDROID_VERSION is required to be defined."
[ -z "${KERNEL_BRANCH}" ] && exit_with_msg "KERNEL_BRANCH is required to be defined."
[ -z "${KERNEL_REPO}" ] && exit_with_msg "KERNEL_REPO is required to be defined."
[ -z "${KERNEL_DESCRIBE}" ] && exit_with_msg "KERNEL_DESCRIBE is required to be defined."
[ -z "${TEST_METADATA_TOOLCHAIN}" ] && exit_with_msg "TEST_METADATA_TOOLCHAIN is required to be defined."
[ -z "${TEST_VTS_URL}" ] && exit_with_msg "TEST_VTS_URL is required to be defined."
[ -z "${TEST_CTS_URL}" ] && exit_with_msg "TEST_CTS_URL is required to be defined."

export ANDROID_VERSION KERNEL_BRANCH KERNEL_REPO TEST_METADATA_TOOLCHAIN TEST_VTS_URL TEST_CTS_URL
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


OPT_DRY_RUN=""
if [ -n "${ENV_DRY_RUN}" ]; then
    OPT_DRY_RUN="--dry-run"
fi

f_temp_path=${F_ABS_PATH}
NEED_CLONE_CONFIGS=true
DIR_GIT_ROOT=""
while true; do
    parent=$(dirname ${f_temp_path})
    if [ -d ${parent}/.git ]; then
        NEED_CLONE_CONFIGS=false
        DIR_GIT_ROOT=${parent}
        break
    elif [ "X${parent}" = "X/" ]; then
        break
    fi
    f_temp_path=${parent}
done
if ${NEED_CLONE_CONFIGS}; then
    rm -rf configs && git clone --depth 1 http://git.linaro.org/ci/job/configs.git && DIR_GIT_ROOT=configs
fi
python ${DIR_GIT_ROOT}/openembedded-lkft/submit_for_testing.py \
    --device-type ${TEST_DEVICE_TYPE} \
    --build-number ${BUILD_NUMBER} \
    --lava-server ${TEST_LAVA_SERVER} \
    --qa-server ${TEST_QA_SERVER} \
    --qa-server-team android-lkft \
    --env-suffix "_4.19" \
    --qa-server-project ${TEST_QA_SERVER_PROJECT} \
    --git-commit ${QA_BUILD_VERSION} \
    --testplan-path ${DIR_GIT_ROOT}/lkft/lava-job-definitions/common \
    --test-plan template-boot.yaml template-vts-kernel.yaml template-cts.yaml \
    ${OPT_DRY_RUN} \
    --quiet
