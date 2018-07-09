#!/bin/bash

set -ex

[ -z "${LAVA_JOB_PRIORITY}" ] && export LAVA_JOB_PRIORITY="low"
[ -z "${SKIP_LAVA}" ] || unset DEVICE_TYPE

if [ -z "${DEVICE_TYPE}" ]; then
    echo "DEVICE_TYPE not set. Exiting"
    exit 0
fi

if [ -n "${DRY_RUN}" ]; then
    ## called from local side for via test_submit_for_testing.sh
    export EXTRA_PARAMS="--dry-run"
    ## path of this android-lcr/common/submit_for_testing.sh
    ## make BASE_PATH to point to the configs directory
    PARENT_DIR=$(cd $(dirname $0); pwd)
    export BASE_PATH=${PARENT_DIR}/../../
else
    ## called via jenkins
    rm -rf configs
    git clone --depth 1 http://git.linaro.org/ci/job/configs.git
    export EXTRA_PARAMS=""
    export BASE_PATH=`pwd`/configs
fi

## set paths to use absolute paths
export SCRIPT_PATH=${BASE_PATH}/openembedded-lkft/
export TESTPLAN_PATH=${BASE_PATH}/android-lcr/lava-job-definitions/
export TEMPLATE_PATH=${BASE_PATH}/android-lcr/lava-job-definitions/

# create env variables as in post-build-lava
export SNAPSHOTS_URL=https://snapshots.linaro.org
export FILE_EXTENSION=tar.bz2
if [ "${MAKE_TARGETS}" = "droidcore" ]; then
    if [ -n "${IMAGE_EXTENSION}" ]; then
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
export CTS_PKG_URL=${CTS_PKG_URL}
export VTS_PKG_URL=${VTS_PKG_URL}
[ -z "${GERRIT_CHANGE_NUMBER}" ] && export GERRIT_CHANGE_NUMBER=""
[ -z "${GERRIT_PATCHSET_NUMBER}" ] && export GERRIT_PATCHSET_NUMBER=""
[ -z "${GERRIT_CHANGE_URL}" ] && export GERRIT_CHANGE_URL=""
[ -z "${GERRIT_CHANGE_ID}" ] && export GERRIT_CHANGE_ID=""
[ -z "${REFERENCE_BUILD_URL}" ] && export REFERENCE_BUILD_URL=""
[ -z "${CTS_MODULE_NAME}" ] && export CTS_MODULE_NAME=""
[ -z "${CTS_PKG_URL}" ] && unset CTS_PKG_URL
[ -z "${VTS_PKG_URL}" ] && unset VTS_PKG_URL
[ -z "${ANDROID_VERSION_SUFFIX}" ] && unset ANDROID_VERSION_SUFFIX


[ ! -z ${TEST_TEMPLATES} ] && unset TEST_TEMPLATES

DEVICE_PLAN=${PLAN_CHANGE:-"plan_change_${DEVICE_TYPE}"}
if [ ! -n "$GERRIT_PROJECT" ]; then
    DEVICE_PLAN=${PLAN_WEEKLY:-"plan_weekly_${DEVICE_TYPE}"}
fi

for test in $(ls ${TESTPLAN_PATH}/${DEVICE_PLAN}); do
    TEST_TEMPLATES="${TEST_TEMPLATES} ${DEVICE_PLAN}/${test}"
done

python ${SCRIPT_PATH}/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --env-suffix ${FRONTEND_JOB_NAME} \
  --build-number ${BUILD_NUMBER} \
  --lava-server ${LAVA_SERVER} \
  --qa-server ${QA_SERVER} \
  --qa-server-team lcr \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${BUILD_NUMBER} \
  --quiet \
  ${EXTRA_PARAMS} \
  --testplan-path ${TESTPLAN_PATH} \
  --template-path ${TEMPLATE_PATH} \
  --test-plan ${TEST_TEMPLATES}
