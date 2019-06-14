#!/bin/bash -ex

cd /home/buildslave/srv/${BUILD_DIR}

F_ABS_PATH=$(readlink -e $0)
OPT_DRY_RUN=""
if [ -n "${ENV_DRY_RUN}" ]; then
    OPT_DRY_RUN="--dry-run"
fi

function exit_with_msg(){
    echo "$@"
    exit
}

function check_environments(){
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
    [ -z "${TEST_METADATA_TOOLCHAIN}" ] && exit_with_msg "TEST_METADATA_TOOLCHAIN is required to be defined."
    [ -z "${TEST_VTS_URL}" ] && exit_with_msg "TEST_VTS_URL is required to be defined."
    [ -z "${TEST_CTS_URL}" ] && exit_with_msg "TEST_CTS_URL is required to be defined."
    [ -z "${REFERENCE_BUILD_URL}" ] && exit_with_msg "REFERENCE_BUILD_URL is required to be defined."

    [ -z "${PUBLISH_FILES}" ] && exit_with_msg "PUBLISH_FILES is required to be defined."

    return 0
}


function submit_jobs_for_config(){
    local build_config=$1 && shift
    # clean environments
    unset TEST_DEVICE_TYPE TEST_LAVA_SERVER TEST_QA_SERVER TEST_QA_SERVER_PROJECT
    unset ANDROID_VERSION KERNEL_BRANCH KERNEL_REPO TEST_METADATA_TOOLCHAIN TEST_VTS_URL TEST_CTS_URL REFERENCE_BUILD_URL
    unset PUBLISH_FILES

    config_url="https://android-git.linaro.org/android-build-configs.git/plain/lkft/${build_config}?h=lkft"
    wget ${config_url} -O ${build_config}
    source ${build_config}

    check_environments
    export ANDROID_VERSION KERNEL_BRANCH KERNEL_REPO TEST_METADATA_TOOLCHAIN TEST_VTS_URL TEST_CTS_URL REFERENCE_BUILD_URL
    export TEST_VTS_VERSION=$(echo ${TEST_VTS_URL} | awk -F"/" '{print$(NF-1)}')
    export TEST_CTS_VERSION=$(echo ${TEST_CTS_URL} | awk -F"/" '{print$(NF-1)}')

    for f in ${PUBLISH_FILES}; do
        # DOWNLOAD_URL is where the generated files stored
        # replace REFERENCE_BUILD_URL with DOWNLOAD_URL
        sed -i "s|{{REFERENCE_BUILD_URL}}/${f}|{{DOWNLOAD_URL}}/$f|" ${DIR_CONFIGS_ROOT}/lkft/lava-job-definitions/common/devices/${TEST_DEVICE_TYPE}
        # replace file name in job template with new file name generated
        sed -i "s|{{DOWNLOAD_URL}}/${f}|{{DOWNLOAD_URL}}/${build_config}-$f|" ${DIR_CONFIGS_ROOT}/lkft/lava-job-definitions/common/devices/${TEST_DEVICE_TYPE}
    done
    OPT_ENV_SUFFIX=""
    if [ -z "{TEST_QA_SERVER_ENV_SUFFIX}" ] && [ "X${TEST_QA_SERVER_ENV_SUFFIX_ENABLED}" == "Xtrue" ]; then
        OPT_ENV_SUFFIX="--env-suffix ${TEST_QA_SERVER_ENV_SUFFIX}"
    fi
    python ${DIR_CONFIGS_ROOT}/openembedded-lkft/submit_for_testing.py \
        --device-type ${TEST_DEVICE_TYPE} \
        --build-number ${BUILD_NUMBER} \
        --lava-server ${TEST_LAVA_SERVER} \
        --qa-server ${TEST_QA_SERVER} \
        --qa-server-team android-lkft \
        ${OPT_ENV_SUFFIX} \
        --qa-server-project ${TEST_QA_SERVER_PROJECT} \
        --git-commit ${QA_BUILD_VERSION} \
        --testplan-path ${DIR_CONFIGS_ROOT}/lkft/lava-job-definitions/common \
        --test-plan template-boot.yaml template-vts-kernel.yaml template-cts.yaml \
        ${OPT_DRY_RUN} \
        --quiet
}

function submit_jobs(){
    local f_temp_path=${F_ABS_PATH}
    local NEED_CLONE_CONFIGS=true
    DIR_CONFIGS_ROOT=""
    while true; do
        parent=$(dirname ${f_temp_path})
        if [ -d ${parent}/.git ]; then
            NEED_CLONE_CONFIGS=false
            DIR_CONFIGS_ROOT=${parent}
            break
        elif [ "X${parent}" = "X/" ]; then
            break
        fi
        f_temp_path=${parent}
    done

    if ${NEED_CLONE_CONFIGS}; then
        rm -rf configs && git clone --depth 1 http://git.linaro.org/ci/job/configs.git && DIR_CONFIGS_ROOT=configs
    fi

    #environments exported by jenkins
    #export BUILD_NUMBER JOB_NAME BUILD_URL

    PUB_DEST=android/lkft/${JOB_NAME}/${BUILD_NUMBER}/
    export DOWNLOAD_URL=http://snapshots.linaro.org/${PUB_DEST}

    # environments set by the upstream trigger job
    KERNEL_COMMIT=${SRCREV_kernel}
    if [ ! -z "${KERNEL_DESCRIBE}" ]; then
        QA_BUILD_VERSION=${KERNEL_DESCRIBE}
    else
        QA_BUILD_VERSION=${KERNEL_COMMIT:0:12}
    fi
    export KERNEL_DESCRIBE KERNEL_COMMIT
    export QA_BUILD_VERSION DIR_CONFIGS_ROOT

    for build_config in ${ANDROID_BUILD_CONFIG}; do
        submit_jobs_for_config ${build_config}
    done
}

submit_jobs "$@"
