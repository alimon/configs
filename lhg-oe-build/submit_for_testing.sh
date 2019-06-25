#!/bin/bash

set -ex

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

PRODUCTION_LAVA_TEST_JOBS="template-robotframework-tests.yaml template-wifi-tests.yaml"
STAGING_LAVA_TEST_JOBS=""

case "${DEVICE_TYPE}" in
  dragonboard-410c)
    PRODUCTION_LAVA_TEST_JOBS="${PRODUCTION_LAVA_TEST_JOBS} template-v4l2-compliance-test.yaml"
    if [ "${MANIFEST_BRANCH}" == "rocko" ]; then
      STAGING_LAVA_TEST_JOBS="template-igt-test.yaml"
      export CHAMELIUM_IP="10.7.0.94"
    fi
    ;;
  am57xx-evm)
    if [ "${MANIFEST_BRANCH}" == "rocko" ]; then
      PRODUCTION_LAVA_TEST_JOBS="template-igt-test.yaml"
      export CHAMELIUM_IP="10.7.0.93"
    fi
    ;;
esac

if [ -n "${DEVICE_TYPE}" ]; then
  [ -z "${PRODUCTION_LAVA_TEST_JOBS}" ] || \
  python configs/openembedded-lkft/submit_for_testing.py \
    --device-type ${DEVICE_TYPE} \
    --build-number ${BUILD_NUMBER} \
    --lava-server ${LAVA_SERVER} \
    --qa-server ${QA_SERVER} \
    --qa-server-team lhg \
    --qa-server-project ${QA_SERVER_PROJECT} \
    --git-commit ${BUILD_NUMBER} \
    --template-path configs/lhg-oe-build/lava-job-definitions \
    --template-names ${PRODUCTION_LAVA_TEST_JOBS}
  
  [ -z "${STAGING_LAVA_TEST_JOBS}" ] || \
  python configs/openembedded-lkft/submit_for_testing.py \
    --device-type ${DEVICE_TYPE} \
    --build-number ${BUILD_NUMBER} \
    --lava-server https://staging.validation.linaro.org/RPC2/ \
    --qa-server ${QA_SERVER} \
    --qa-server-team lhg \
    --qa-server-project ${QA_SERVER_PROJECT} \
    --git-commit ${BUILD_NUMBER} \
    --template-path configs/lhg-oe-build/lava-job-definitions \
    --template-names ${STAGING_LAVA_TEST_JOBS}
fi
