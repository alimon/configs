#!/bin/bash

set -ex

QA_BUILD_VERSION=${MANIFEST_COMMIT:0:12}

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

[ -z "${DEVICE_TYPE}" ] || \
python configs/openembedded-lkft/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --build-number ${BUILD_NUMBER} \
  --lava-server ${LAVA_SERVER} \
  --qa-server ${QA_SERVER} \
  --qa-server-team lhg \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${QA_BUILD_VERSION} \
  --template-path configs/lhg-oe-build/lava-job-definitions \
  --template-names template-eme-clearkey.yaml
