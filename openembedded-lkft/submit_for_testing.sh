#!/bin/bash

set -ex

[ -z "${KSELFTEST_PATH}" ] && export KSELFTEST_PATH="/opt/kselftests/mainline/"
[ -z "${LAVA_JOB_PRIORITY}" ] && export LAVA_JOB_PRIORITY="25"
[ -z "${SANITY_LAVA_JOB_PRIORITY}" ] && export SANITY_LAVA_JOB_PRIORITY="30"
[ -z "${SKIP_LAVA}" ] || unset DEVICE_TYPE
[ -z "${QA_SERVER_TEAM}" ] && export QA_SERVER_TEAM=lkft
[ -z "${TOOLCHAIN}" ] && export TOOLCHAIN="unknown"

if [ -n "${DRY_RUN}" ]; then
    export DRY_RUN="--dry-run --template-path lava-job-definitions --testplan-path lava-job-definitions/ --quiet"
    export BASE_PATH=.
else
    export DRY_RUN=""
    export BASE_PATH=configs/openembedded-lkft/
fi

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
fi

if [ ! -z "${KERNEL_DESCRIBE}" ]; then
    export QA_BUILD_VERSION=${KERNEL_DESCRIBE}
else
    export QA_BUILD_VERSION=${KERNEL_COMMIT:0:12}
fi

if [ -z "${DRY_RUN}" ]; then
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
fi

[ ! -z ${FULL_TEST_TEMPLATES} ] && unset FULL_TEST_TEMPLATES
TEMPLATE_PATH=""

# Generate list of job templates for full test run
for test in $(ls ${BASE_PATH}/lava-job-definitions/testplan/); do
    if [[ ${test} = "ltp-open-posix.yaml" ]];then
        # Run LTP open posix test suite on limited devices
        # Each one per architecture arm64 juno-r2, arm32 x15 and x86
        if [[ ${DEVICE_TYPE} = "juno-r2" || ${DEVICE_TYPE} = "x15" || ${DEVICE_TYPE} = "x86" ]];then
            FULL_TEST_TEMPLATES="${FULL_TEST_TEMPLATES} testplan/${test}"
        fi
    elif  [[ ${test} = "kselftests-native.yaml" || ${test} = "kselftests-none.yaml" ]];then
        # kselftests-native.yaml and kselftests-none.yaml tests needed for x86
        # Don't run on qemu; it's not possible to pass a kernel argument
        # given the way we build the image and run qemu.
        if [[ ${DEVICE_TYPE} = "x86" ]];then
            FULL_TEST_TEMPLATES="${FULL_TEST_TEMPLATES} testplan/${test}"
        fi
    else
        FULL_TEST_TEMPLATES="${FULL_TEST_TEMPLATES} testplan/${test}"
    fi
done

if [[ ${DEVICE_TYPE} = "juno-r2" || ${DEVICE_TYPE} = "x15" || ${DEVICE_TYPE} = "x86" ]];then
    [ ! -z ${SANITY_TEST_TEMPLATES} ] && unset SANITY_TEST_TEMPLATES

    # Save original priority
    export FULL_LAVA_JOB_PRIORITY=${LAVA_JOB_PRIORITY}

    # Bump priority for the sanity jobs
    export LAVA_JOB_PRIORITY=${SANITY_LAVA_JOB_PRIORITY}

    # Generate list of job templates for sanity test run
    for test in $(ls ${BASE_PATH}/lava-job-definitions/testplan-sanity/); do
        SANITY_TEST_TEMPLATES="${SANITY_TEST_TEMPLATES} testplan-sanity/${test}"
    done

    # Submit sanity test run
    python ${BASE_PATH}/submit_for_testing.py \
      --device-type ${DEVICE_TYPE} \
      --build-number ${BUILD_NUMBER} \
      --lava-server ${LAVA_SERVER} \
      --qa-server ${QA_SERVER} \
      --qa-server-team ${QA_SERVER_TEAM} \
      --qa-server-project ${QA_SERVER_PROJECT}-sanity \
      --git-commit ${QA_BUILD_VERSION} \
      ${DRY_RUN} \
      --test-plan ${SANITY_TEST_TEMPLATES}

    # reset LAVA_JOB_PRIORITY to default
    export LAVA_JOB_PRIORITY=${FULL_LAVA_JOB_PRIORITY}
fi

# Submit full test run
python ${BASE_PATH}/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --build-number ${BUILD_NUMBER} \
  --lava-server ${LAVA_SERVER} \
  --qa-server ${QA_SERVER} \
  --qa-server-team ${QA_SERVER_TEAM} \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${QA_BUILD_VERSION} \
  ${DRY_RUN} \
  --test-plan ${FULL_TEST_TEMPLATES}
