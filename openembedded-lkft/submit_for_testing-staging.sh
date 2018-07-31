#!/bin/bash

set -ex

echo "v---env---v"
env
echo "^---env---^"

[ -z "${KSELFTEST_PATH}" ] && export KSELFTEST_PATH="/opt/kselftests/mainline/"
[ -z "${LAVA_JOB_PRIORITY}" ] && export LAVA_JOB_PRIORITY="25"
[ -z "${SKIP_LAVA}" ] || unset DEVICE_TYPE
[ -z "${QA_SERVER_TEAM}" ] && export QA_SERVER_TEAM=lkft
[ -z "${TOOLCHAIN}" ] && export TOOLCHAIN="unknown"
[ -z "${KERNEL_COMMIT}" ] && export KERNEL_COMMIT="${KERNEL_SRCREV}"
[ -z "${MAKE_KERNELVERSION}" ] && export MAKE_KERNELVERSION="unknown"
[ -z "${KERNEL_VERSION}" ] && export KERNEL_VERSION="unknown"
[ -z "${KERNEL_DESCRIBE}" ] && export KERNEL_DESCRIBE=${KERNEL_SRCREV:0:12}

[ "${TEST_SUITES}" = "none" ] && unset DEVICE_TYPE

export BASE_PATH=configs/openembedded-lkft/

if [ -z "${DEVICE_TYPE}" ]; then
    echo "DEVICE_TYPE not set. Exiting"
    exit 0
fi

if [ -z "${DRY_RUN}" ]; then
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

    rm -rf configs

    # Perform a shallow clone unless CONFIGS_REPO_REV_OVERRIDE is set
    CONFIGS_REPO_CLONE_ARGS="--depth 1"
    if [ ! -z ${CONFIGS_REPO_REV_OVERRIDE} ]; then
        CONFIGS_REPO_CLONE_ARGS=""
    fi

    CONFIGS_REPO_URL=${CONFIGS_REPO_URL_OVERRIDE:-http://git.linaro.org/ci/job/configs.git}
    git clone ${CONFIGS_REPO_CLONE_ARGS} ${CONFIGS_REPO_URL} configs
    if [ ! -z ${CONFIGS_REPO_REV_OVERRIDE} ]; then
        (cd configs && git checkout ${CONFIGS_REPO_REV_OVERRIDE})
    fi
else
    export DRY_RUN="--dry-run --template-path lava-job-definitions --testplan-path lava-job-definitions/ --quiet"
fi

export QA_BUILD_VERSION=${KERNEL_DESCRIBE}

[ -n "${TEST_TEMPLATES}" ] && unset TEST_TEMPLATES
[ -z "${TEST_SUITES}" ] && TEST_SUITES=all
TEMPLATE_PATH=""
TEST_FILES=""

for ts in ${TEST_SUITES,,}; do
    case ${ts} in
        all)
            TEST_FILES=$(ls ${BASE_PATH}/lava-job-definitions/testplan/)
            break
            ;;
        none)
            TEST_FILES=
            break
            ;;
        kselftests)
            TEST_FILES="${TEST_FILES} $(basename -a ${BASE_PATH}/lava-job-definitions/testplan/kselftests*.yaml)"
            ;;
        libhugetlbfs)
            TEST_FILES="${TEST_FILES} $(basename -a ${BASE_PATH}/lava-job-definitions/testplan/libhugetlbfs*.yaml)"
            ;;
        ltp)
            TEST_FILES="${TEST_FILES} $(basename -a ${BASE_PATH}/lava-job-definitions/testplan/ltp*.yaml)"
            ;;
        *)
            echo "WARNING: Not sure what this test suite is about: ${ts}. Skipped."
            ;;
    esac
done

for test in ${TEST_FILES}; do
    if [[ ${test} = "ltp-open-posix.yaml" ]];then
        # Run LTP open posix test suite on limited devices
        # Each one per architecture arm64 juno-r2, arm32 x15 and x86
        if [[ ${DEVICE_TYPE} = "juno-r2" || ${DEVICE_TYPE} = "x15" || ${DEVICE_TYPE} = "x86" ]];then
            TEST_TEMPLATES="${TEST_TEMPLATES} testplan/${test}"
        fi
    elif  [[ ${test} = "kselftests-native.yaml" || ${test} = "kselftests-none.yaml" ]];then
        # kselftests-native.yaml and kselftests-none.yaml tests needed for x86
        # Don't run on qemu; it's not possible to pass a kernel argument
        # given the way we build the image and run qemu.
        if [[ ${DEVICE_TYPE} = "x86" ]];then
            TEST_TEMPLATES="${TEST_TEMPLATES} testplan/${test}"
        fi
    else
        TEST_TEMPLATES="${TEST_TEMPLATES} testplan/${test}"
    fi
done

python ${BASE_PATH}/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --build-number ${BUILD_NUMBER} \
  --lava-server ${LAVA_SERVER} \
  --qa-server ${QA_SERVER} \
  --qa-server-team ${QA_SERVER_TEAM} \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${QA_BUILD_VERSION} \
  ${DRY_RUN} \
  --test-plan ${TEST_TEMPLATES}
