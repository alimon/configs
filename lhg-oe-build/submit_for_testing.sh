#!/bin/bash

set -ex

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

TEST_JOBS="template-tests-${MANIFEST_BRANCH}.yaml template-wifi-tests.yaml"
[ "${DEVICE_TYPE}" == "dragonboard-410c" ] && TEST_JOBS="${TEST_JOBS} template-v4l2-compliance-test.yaml"

[ -z "${DEVICE_TYPE}" ] || \
python configs/openembedded-lkft/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --build-number ${BUILD_NUMBER} \
  --lava-server ${LAVA_SERVER} \
  --qa-server ${QA_SERVER} \
  --qa-server-team lhg \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${BUILD_NUMBER} \
  --template-path configs/lhg-oe-build/lava-job-definitions \
  --template-names ${TEST_JOBS}

# DB410c igt test only runs with rocko build and on staging LAVA
[ "${DEVICE_TYPE}" == "dragonboard-410c" ] && [ "${MANIFEST_BRANCH}" == "rocko" ] && \
export CHAMELIUM_IP="10.7.0.94" && \
python configs/openembedded-lkft/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --build-number ${BUILD_NUMBER} \
  --lava-server https://staging.validation.linaro.org/RPC2/ \
  --qa-server ${QA_SERVER} \
  --qa-server-team lhg \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${BUILD_NUMBER} \
  --template-path configs/lhg-oe-build/lava-job-definitions \
  --template-names template-igt-test.yaml
