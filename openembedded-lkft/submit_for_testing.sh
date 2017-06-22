#!/bin/bash

set -e

export KSELFTEST_SKIPLIST=""

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

python configs/openembedded-lkft/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --build-number ${BUILD_NUMBER} \
  --lava-server https://lkft.${LAVA_SERVER} \
  --qa-server ${QA_SERVER} \
  --qa-server-team lkft \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${KERNEL_COMMIT} \
  --template-names template-kselftest.yaml template-ltp.yaml template-libhugetlbfs.yaml
