#!/bin/bash

set -ex

[ -z "${DEVICE_TYPE}" ] && export DEVICE_TYPE="hi6220-hikey-r2"
[ -z "${LAVA_JOB_PRIORITY}" ] && export LAVA_JOB_PRIORITY="25"
[ -z "${SKIP_LAVA}" ] || unset DEVICE_TYPE
[ -z "${QA_SERVER_TEAM}" ] && export QA_SERVER_TEAM="ledge"

if [ -n "${DRY_RUN}" ]; then
    export DRY_RUN="--dry-run --template-path lava-job-definitions --testplan-path lava-job-definitions/ --quiet"
    export BASE_PATH=.
else
    export DRY_RUN=""
    export BASE_PATH=configs/osf-linux-microplatform/
fi

if [ -z "${DEVICE_TYPE}" ]; then
    echo "DEVICE_TYPE not set. Exiting"
    exit 0
fi

if [ -z "${DRY_RUN}" ]; then
    rm -rf configs

    # Perform a shallow clone unless CONFIGS_REPO_REV_OVERRIDE is set
    CONFIGS_REPO_CLONE_ARGS="--depth 1"
    if [ -n ${CONFIGS_REPO_REV_OVERRIDE} ]; then
        CONFIGS_REPO_CLONE_ARGS=""
    fi

    CONFIGS_REPO_URL=${CONFIGS_REPO_URL_OVERRIDE:-http://git.linaro.org/ci/job/configs.git}
    git clone ${CONFIGS_REPO_CLONE_ARGS} ${CONFIGS_REPO_URL} configs
    if [ -n ${CONFIGS_REPO_REV_OVERRIDE} ]; then
        (cd configs && git checkout ${CONFIGS_REPO_REV_OVERRIDE})
    fi
fi

export QA_BUILD_VERSION=${BUILD_NUMBER}

[ -n ${FULL_TEST_TEMPLATES} ] && unset FULL_TEST_TEMPLATES
TEMPLATE_PATH=""
# Generate list of job templates for full test run
for test in $(ls ${BASE_PATH}/lava-job-definitions/testplan/); do
    FULL_TEST_TEMPLATES="${FULL_TEST_TEMPLATES} testplan/${test}"
done

# Submit full test run
python2 ${BASE_PATH}/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --build-number ${BUILD_NUMBER} \
  --lava-server ${LAVA_SERVER} \
  --qa-server ${QA_SERVER} \
  --qa-server-team ${QA_SERVER_TEAM} \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${QA_BUILD_VERSION} \
  ${DRY_RUN} \
  --test-plan ${FULL_TEST_TEMPLATES}
