#!/bin/bash

set -ex

[ -z "${KSELFTEST_PATH}" ] && export KSELFTEST_PATH="/opt/kselftests/mainline/"
[ -z "${LAVA_JOB_PRIORITY}" ] && export LAVA_JOB_PRIORITY="low"
[ -z "${SKIP_LAVA}" ] || unset DEVICE_TYPE

if [ -z "${DEVICE_TYPE}" ]; then
    echo "DEVICE_TYPE not set. Exiting"
    exit 0
fi

case "${QA_SERVER_PROJECT}" in
  linux-mainline-*)
    source /srv/oe/build/lkftmetadata/packages/*/${KERNEL_RECIPE}/metadata
    export KSELFTESTS_URL=${LINUX_GENERIC_MAINLINE_URL}
    export KSELFTESTS_VERSION=${LINUX_GENERIC_MAINLINE_VERSION}
    export KSELFTESTS_REVISION=${KERNEL_COMMIT}
    ;;
  linux-next-*)
    source /srv/oe/build/lkftmetadata/packages/*/${KERNEL_RECIPE}/metadata
    export KSELFTESTS_URL=${LINUX_GENERIC_NEXT_URL}
    export KSELFTESTS_VERSION=${LINUX_GENERIC_NEXT_VERSION}
    export KSELFTESTS_REVISION=${KERNEL_COMMIT}
    ;;
  *)
    export KSELFTESTS_URL=${KSELFTESTS_MAINLINE_URL}
    export KSELFTESTS_VERSION=${KSELFTESTS_MAINLINE_VERSION}
    export KSELFTESTS_REVISION=${KSELFTESTS_MAINLINE_VERSION}
    ;;
esac

if [ ! -z "${KERNEL_DESCRIBE}" ]; then
    export QA_BUILD_VERSION=${KERNEL_DESCRIBE}
else
    export QA_BUILD_VERSION=${KERNEL_COMMIT:0:12}
fi

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

[ ! -z ${TEST_TEMPLATES} ] && unset TEST_TEMPLATES

for test in $(ls configs/openembedded-lkft/lava-job-definitions/testplan); do
    TEST_TEMPLATES="${TEST_TEMPLATES} testplan/${test}"
done

python configs/openembedded-lkft/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --build-number ${BUILD_NUMBER} \
  --lava-server ${LAVA_SERVER} \
  --qa-server ${QA_SERVER} \
  --qa-server-team lkft \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${QA_BUILD_VERSION} \
  --test-plan ${TEST_TEMPLATES}
