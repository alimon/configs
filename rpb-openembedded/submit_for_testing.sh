#!/bin/bash

[ -z "${KSELFTEST_PATH}" ] && export KSELFTEST_PATH="/opt/kselftests/mainline/"
[ -z "${LAVA_JOB_PRIORITY}" ] && export LAVA_JOB_PRIORITY="25"
[ -z "${SANITY_LAVA_JOB_PRIORITY}" ] && export SANITY_LAVA_JOB_PRIORITY="30"
[ -z "${SKIP_LAVA}" ] || unset DEVICE_TYPE
[ -z "${QA_SERVER_TEAM}" ] && export QA_SERVER_TEAM=rpb
[ -z "${TOOLCHAIN}" ] && export TOOLCHAIN="unknown"
[ -z "${TDEFINITIONS_REVISION}" ] && export TDEFINITIONS_REVISION="kselftest-5.1"
[ -z "${MANIFEST_COMMIT}" ] && export MANIFEST_COMMIT="HEAD"

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git
# for manual run from current directory
#git clone --depth 1 . configs

# Used by DB410C's template:
export RESIZE_ROOTFS=${RESIZE_ROOTFS:-}

[ -z "${DEVICE_TYPE}" ] || \
python configs/openembedded-lkft/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --build-number ${BUILD_NUMBER} \
  --lava-server ${LAVA_SERVER} \
  --qa-server ${QA_SERVER} \
  --qa-server-team ${QA_SERVER_TEAM} \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${MANIFEST_COMMIT} \
  --template-path configs/rpb-openembedded/lava-job-definitions \
  --template-names template-boot.yaml
