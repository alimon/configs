#!/bin/bash

#set -ex

[ -z "${LAVA_JOB_PRIORITY}" ] && export LAVA_JOB_PRIORITY="low"
[ -z "${SKIP_LAVA}" ] || unset DEVICE_TYPE

if [ -n "${DRY_RUN}" ]; then
    export DRY_RUN="--dry-run --template-path ../lava-job-definitions --testplan-path ../lava-job-definitions/ --quiet"
    export BASE_PATH=../
    export SCRIPT_PATH=../../openembedded-lkft/
else
    export DRY_RUN=""
    export BASE_PATH=configs/android-lcr/
    export SCRIPT_PATH=configs/openembedded-lkft/
fi

if [ -z "${DEVICE_TYPE}" ]; then
    echo "DEVICE_TYPE not set. Exiting"
    exit 0
fi

# create env variables as in post-build-lava
export SNAPSHOTS_URL=https://snapshots.linaro.org
export FILE_EXTENSION=tar.bz2
if [ "${MAKE_TARGETS}" = "droidcore" ]; then
    if [ -z "$IMAGE_EXTENSION" ]; then
        export FILE_EXTENSION=${IMAGE_EXTENSION}
    else
        export FILE_EXTENSION=img
    fi
fi
if [ -z "${FRONTEND_JOB_NAME}" ]; then
    export FRONTEND_JOB_NAME=~$(echo ${JOB_NAME} | sed -e 's/_/\//')
fi
if [ -z "${DOWNLOAD_URL}" ]; then
    export DOWNLOAD_URL=${SNAPSHOTS_URL}/android/${FRONTEND_JOB_NAME}/${BUILD_NUMBER}
fi
export ANDROID_BOOT=${DOWNLOAD_URL}/boot.${FILE_EXTENSION}
export ANDROID_SYSTEM=${DOWNLOAD_URL}/system.${FILE_EXTENSION}
export ANDROID_DATA=${DOWNLOAD_URL}/userdata.${FILE_EXTENSION}
export ANDROID_CACHE=${DOWNLOAD_URL}/cache.${FILE_EXTENSION}
export ANDROID_META_NAME=${JOB_NAME}
export ANDROID_META_BUILD=${BUILD_NUMBER}
export ANDROID_META_URL=${BUILD_URL}
export WA2_JOB_NAME=${BUILD_NUMBER}
[ -z "${GERRIT_CHANGE_NUMBER}" ] && export GERRIT_CHANGE_NUMBER=""
[ -z "${GERRIT_PATCHSET_NUMBER}" ] && export GERRIT_PATCHSET_NUMBER=""
[ -z "${GERRIT_CHANGE_URL}" ] && export GERRIT_CHANGE_URL=""
[ -z "${GERRIT_CHANGE_ID}" ] && export GERRIT_CHANGE_ID=""
[ -z "${REFERENCE_BUILD_URL}" ] && export REFERENCE_BUILD_URL=""
[ -z "${CTS_MODULE_NAME}" ] && export CTS_MODULE_NAME=""

if [ -z "${DRY_RUN}" ]; then
    rm -rf configs
    git clone --depth 1 http://git.linaro.org/ci/job/configs.git
fi

[ ! -z ${TEST_TEMPLATES} ] && unset TEST_TEMPLATES
TEMPLATE_PATH=""

for test in $(ls ${BASE_PATH}/lava-job-definitions/testplan/); do
    TEST_TEMPLATES="${TEST_TEMPLATES} testplan/${test}"
done

python ${SCRIPT_PATH}/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --env-suffix ${FRONTEND_JOB_NAME} \
  --build-number ${BUILD_NUMBER} \
  --lava-server ${LAVA_SERVER} \
  --qa-server ${QA_SERVER} \
  --qa-server-team lmg \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${BUILD_NUMBER} \
  ${DRY_RUN} \
  --test-plan ${TEST_TEMPLATES}
