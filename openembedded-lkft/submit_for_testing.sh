#!/bin/bash

set -e

export KSELFTEST_SKIPLIST=""

if [ -z "${KERNEL_DESCRIBE}" ]; then
    export QA_BUILD_VERSION="${KERNEL_DESCRIBE}"
else
    export QA_BUILD_VERSION=${KERNEL_COMMIT:0:12}
fi

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

python configs/openembedded-lkft/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --build-number ${BUILD_NUMBER} \
  --lava-server https://lkft.${LAVA_SERVER} \
  --qa-server ${QA_SERVER} \
  --qa-server-team lkft \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${QA_BUILD_VERSION} \
  --template-names template-kselftest.yaml template-ltp.yaml template-libhugetlbfs.yaml
