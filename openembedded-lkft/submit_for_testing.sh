#!/bin/bash

set -ex

[ -z "${KSELFTEST_PATH}" ] && export KSELFTEST_PATH="/opt/kselftests/mainline/"
[ -z "${LAVA_JOB_PRIORITY}" ] && export LAVA_JOB_PRIORITY="25"
[ -z "${SANITY_LAVA_JOB_PRIORITY}" ] && export SANITY_LAVA_JOB_PRIORITY="30"
[ -z "${SKIP_LAVA}" ] || unset DEVICE_TYPE
[ -z "${QA_SERVER_TEAM}" ] && export QA_SERVER_TEAM=lkft
[ -z "${TOOLCHAIN}" ] && export TOOLCHAIN="unknown"
[ -z "${TDEFINITIONS_REVISION}" ] && export TDEFINITIONS_REVISION="kselftest-5.1"

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
    METADATA=${WORKSPACE}/lkftmetadata/${KERNEL_RECIPE}
    [ "${DISTRO}" = "rpb" ] && METADATA=/srv/oe/build/lkftmetadata/packages/*/${KERNEL_RECIPE}/metadata
    case "${QA_SERVER_PROJECT}" in
      linux-mainline-*)
        source ${METADATA}
        export KSELFTESTS_URL=${LINUX_GENERIC_MAINLINE_URL}
        export KSELFTESTS_VERSION=${LINUX_GENERIC_MAINLINE_VERSION}
        export KSELFTESTS_REVISION=${KERNEL_COMMIT}
        export TDEFINITIONS_REVISION="kselftest"
        ;;
      linux-next-*)
        source ${METADATA}
        export KSELFTESTS_URL=${LINUX_GENERIC_NEXT_URL}
        export KSELFTESTS_VERSION=${LINUX_GENERIC_NEXT_VERSION}
        export KSELFTESTS_REVISION=${KERNEL_COMMIT}
        export TDEFINITIONS_REVISION="kselftest"
        ;;
      *)
        export KSELFTESTS_URL=${KSELFTESTS_MAINLINE_URL}
        export KSELFTESTS_VERSION=${KSELFTESTS_MAINLINE_VERSION}
        export KSELFTESTS_REVISION=${KSELFTESTS_MAINLINE_VERSION}
        ;;
    esac
fi

if [ ! -z "${KERNEL_DESCRIBE}" ]; then
    export QA_BUILD_VERSION=${KERNEL_DESCRIBE}${KERNEL_DESCRIBE_SUFFIX}
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

[ -n "${FULL_TEST_TEMPLATES}" ] && unset FULL_TEST_TEMPLATES
[ -n "${QEMU_TEST_TEMPLATES}" ] && unset QEMU_TEST_TEMPLATES
[ -z "${TEST_SUITES}" ] && TEST_SUITES=all
TEMPLATE_PATH=""
TEST_FILES=""

# Generate list of job templates for full test run
for ts in ${TEST_SUITES,,}; do
    case ${ts} in
        all)
            TEST_FILES=$(ls ${BASE_PATH}/lava-job-definitions/testplan/)
            ;;
        none)
            break
            ;;
        kselftests|libhugetlbfs|ltp|perf)
            TEST_FILES="${TEST_FILES} $(basename -a ${BASE_PATH}/lava-job-definitions/testplan/${ts}*.yaml)"
            ;;
        *)
            if [ -e ${BASE_PATH}/lava-job-definitions/testplan/${ts}.yaml ]; then
                TEST_FILES="${TEST_FILES} ${ts}.yaml"
            else
                echo "WARNING: Not sure what this test suite is about: ${ts}. Skipped."
            fi
            ;;
    esac

    case ${ts} in
        all|sanity)
            # Generate list of job templates for sanity test run
            for test in $(ls ${BASE_PATH}/lava-job-definitions/testplan-sanity/); do
                SANITY_TEST_TEMPLATES="${SANITY_TEST_TEMPLATES} testplan-sanity/${test}"
            done
            ;;
    esac
done

for test in ${TEST_FILES}; do
    if [[ ${test} = "ltp-open-posix.yaml" ]];then
        # Run LTP open posix test suite on limited devices
        # Each one per architecture arm64 juno-r2, arm32 x15 and x86
        if [[ ${DEVICE_TYPE} = "juno-r2" || ${DEVICE_TYPE} = "x15" || ${DEVICE_TYPE} = "x86" || ${DEVICE_TYPE} = "i386" ]];then
            FULL_TEST_TEMPLATES="${FULL_TEST_TEMPLATES} testplan/${test}"
        fi
    elif  [[ ${test} = "kselftests-native.yaml" || ${test} = "kselftests-none.yaml" ]];then
        # kselftests-native.yaml and kselftests-none.yaml tests needed for x86
        # Don't run on qemu; it's not possible to pass a kernel argument
        # given the way we build the image and run qemu.
        if [[ ${DEVICE_TYPE} = "x86" ]];then
            FULL_TEST_TEMPLATES="${FULL_TEST_TEMPLATES} testplan/${test}"
        fi
    elif [[ ${test} = "kvm-unit-tests.yaml" ]];then
        if [[ ${DEVICE_TYPE} = "juno-r2" || ${DEVICE_TYPE} = "x86" ]];then
            FULL_TEST_TEMPLATES="${FULL_TEST_TEMPLATES} testplan/${test}"
        fi
    elif [[ ${test} = "ssuite.yaml" ]];then
        if [[ ${DEVICE_TYPE} = "x86" || ${DEVICE_TYPE} = "x15" ]];then
            if [[ ${DEVICE_TYPE} = "x15" && "${MAKE_KERNELVERSION}" == 4.4* ]];then
                echo "no testplan for ${DEVICE_TYPE} and kernel verison: ${MAKE_KERNELVERSION}"
            else
                FULL_TEST_TEMPLATES="${FULL_TEST_TEMPLATES} testplan/${test}"
            fi
        fi
    elif [[ ${test} = "network-basic-tests.yaml" ]];then
        if [[ ${DEVICE_TYPE} != "dragonboard-410c" ]];then
            FULL_TEST_TEMPLATES="${FULL_TEST_TEMPLATES} testplan/${test}"
        fi
    else
        FULL_TEST_TEMPLATES="${FULL_TEST_TEMPLATES} testplan/${test}"
        QEMU_TEST_TEMPLATES="${QEMU_TEST_TEMPLATES} testplan/${test}"
    fi
done

# MIGRATION TO LKFT 2.0
#
# The following tests are already part of the lkft-full
# test plan from lava-test-plans:
# * kvm-unit-tests
# * libhugetlbfs
# * LTP
# * spectre-meltdown-checker
# * v4l2-compliance
# so we need to remove them from here for the combinations
# that have been migrated to LKFT 2.0.

# The list of migrated combinations is here, in the form of
#   QA_PROJECT::LAVA_DEVICE
# one per line, in the following array:
MIGRATED=(
  linux-mainline-master::dragonboard-410c
  linux-next-master::dragonboard-410c
  linux-stable-rc-linux-4.9.y::dragonboard-410c
  linux-stable-rc-linux-4.14.y::dragonboard-410c
  linux-stable-rc-linux-4.19.y::dragonboard-410c
  linux-stable-rc-linux-5.4.y::dragonboard-410c
  linux-stable-rc-5.5-oe::dragonboard-410c
  linux-stable-rc-5.6-oe::dragonboard-410c
  linux-stable-rc-5.7-oe::dragonboard-410c
  linux-stable-rc-linux-5.8.y::dragonboard-410c
  linux-stable-rc-linux-5.9.y::dragonboard-410c
  linux-stable-rc-linux-5.10.y::dragonboard-410c
  linux-stable-rc-linux-5.11.y::dragonboard-410c
  linux-mainline-master::hi6220-hikey
  linux-next-master::hi6220-hikey
  linux-stable-rc-linux-4.9.y::hi6220-hikey
  linux-stable-rc-linux-4.14.y::hi6220-hikey
  linux-stable-rc-linux-4.19.y::hi6220-hikey
  linux-stable-rc-linux-5.4.y::hi6220-hikey
  linux-stable-rc-5.5-oe::hi6220-hikey
  linux-stable-rc-5.6-oe::hi6220-hikey
  linux-stable-rc-5.7-oe::hi6220-hikey
  linux-stable-rc-linux-5.8.y::hi6220-hikey
  linux-stable-rc-linux-5.9.y::hi6220-hikey
  linux-stable-rc-linux-5.10.y::hi6220-hikey
  linux-stable-rc-linux-5.11.y::hi6220-hikey
  linux-mainline-master::juno-r2
  linux-next-master::juno-r2
  linux-stable-rc-linux-4.4.y::juno-r2
  linux-stable-rc-linux-4.9.y::juno-r2
  linux-stable-rc-linux-4.14.y::juno-r2
  linux-stable-rc-linux-4.19.y::juno-r2
  linux-stable-rc-linux-5.4.y::juno-r2
  linux-stable-rc-5.5-oe::juno-r2
  linux-stable-rc-5.6-oe::juno-r2
  linux-stable-rc-5.7-oe::juno-r2
  linux-stable-rc-linux-5.8.y::juno-r2
  linux-stable-rc-linux-5.9.y::juno-r2
  linux-stable-rc-linux-5.10.y::juno-r2
  linux-stable-rc-linux-5.11.y::juno-r2
  linux-mainline-master::i386
  linux-next-master::i386
  linux-stable-rc-linux-4.4.y::i386
  linux-stable-rc-linux-4.9.y::i386
  linux-stable-rc-linux-4.14.y::i386
  linux-stable-rc-linux-4.19.y::i386
  linux-stable-rc-linux-5.4.y::i386
  linux-stable-rc-5.5-oe::i386
  linux-stable-rc-5.6-oe::i386
  linux-stable-rc-5.7-oe::i386
  linux-stable-rc-linux-5.8.y::i386
  linux-stable-rc-linux-5.9.y::i386
  linux-stable-rc-linux-5.10.y::i386
  linux-stable-rc-linux-5.11.y::i386
  linux-mainline-master::x15
  linux-next-master::x15
  linux-stable-rc-linux-4.4.y::x15
  linux-stable-rc-linux-4.9.y::x15
  linux-stable-rc-linux-4.14.y::x15
  linux-stable-rc-linux-4.19.y::x15
  linux-stable-rc-linux-5.4.y::x15
  linux-stable-rc-5.5-oe::x15
  linux-stable-rc-5.6-oe::x15
  linux-stable-rc-5.7-oe::x15
  linux-stable-rc-linux-5.8.y::x15
  linux-stable-rc-linux-5.9.y::x15
  linux-stable-rc-linux-5.10.y::x15
  linux-stable-rc-linux-5.11.y::x15
  linux-mainline-master::x86
  linux-next-master::x86
  linux-stable-rc-linux-4.4.y::x86
  linux-stable-rc-linux-4.9.y::x86
  linux-stable-rc-linux-4.14.y::x86
  linux-stable-rc-linux-4.19.y::x86
  linux-stable-rc-linux-5.4.y::x86
  linux-stable-rc-5.5-oe::x86
  linux-stable-rc-5.6-oe::x86
  linux-stable-rc-5.7-oe::x86
  linux-stable-rc-linux-5.8.y::x86
  linux-stable-rc-linux-5.9.y::x86
  linux-stable-rc-linux-5.10.y::x86
  linux-stable-rc-linux-5.11.y::x86
)

this_combo="${QA_SERVER_PROJECT}::${DEVICE_TYPE}"
if [[ ${MIGRATED[*]} =~ ${this_combo} ]]; then
    echo "This combination (${DEVICE_TYPE} in ${QA_SERVER_PROJECT}) has been"
    echo "migrated to LKFT 2.0. Tests running there will be filtered out here."

    NEW_FULL_TEST_TEMPLATES=""
    for t in ${FULL_TEST_TEMPLATES}; do
        test="${t#testplan/*}"
        test="${test%%.yaml}"
        case ${test} in
            ltp*)            test=""   ;;
            libhugetlbfs)    test=""   ;;
            kvm-unit-tests)  test=""   ;;
            v4l2-compliance) test=""   ;;
            *)               test="$t" ;;
        esac
        [ -z "${test}" ] && echo "LKFT2.0 filtering: $t"
        NEW_FULL_TEST_TEMPLATES="${NEW_FULL_TEST_TEMPLATES} ${test}"
    done
    FULL_TEST_TEMPLATES="${NEW_FULL_TEST_TEMPLATES}"
fi

# Submit sanity jobs
if false; then
    # Save original priority
    export FULL_LAVA_JOB_PRIORITY=${LAVA_JOB_PRIORITY}

    # Bump priority for the sanity jobs
    export LAVA_JOB_PRIORITY=${SANITY_LAVA_JOB_PRIORITY}

    # Submit sanity test run
    if [ ! -z "${SANITY_TEST_TEMPLATES}" ]; then
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
    fi

    # reset LAVA_JOB_PRIORITY to default
    export LAVA_JOB_PRIORITY=${FULL_LAVA_JOB_PRIORITY}
fi

# Submit QEMU jobs
QEMU_DEVICE_TYPE=""
case "${DEVICE_TYPE}" in
  x15)
    QEMU_DEVICE_TYPE=qemu_arm
    ;;
  juno-r2)
    QEMU_DEVICE_TYPE=qemu_arm64
    ;;
  i386)
    QEMU_DEVICE_TYPE=qemu_i386
    ;;
  x86)
    QEMU_DEVICE_TYPE=qemu_x86_64
    ;;
esac
if false; then
  # submit_for_testing.py sends the current environment to jinja, and jinja
  # templates rely on DEVICE_TYPE. so we have to actually set DEVICE_TYPE here.
  export ORIGINAL_DEVICE_TYPE=${DEVICE_TYPE}
  export DEVICE_TYPE=${QEMU_DEVICE_TYPE}
  python ${BASE_PATH}/submit_for_testing.py \
    --device-type ${QEMU_DEVICE_TYPE} \
    --build-number ${BUILD_NUMBER} \
    --lava-server ${LAVA_SERVER} \
    --qa-server ${QA_SERVER} \
    --qa-server-team ${QA_SERVER_TEAM} \
    --qa-server-project ${QA_SERVER_PROJECT} \
    --git-commit ${QA_BUILD_VERSION} \
    ${DRY_RUN} \
    --test-plan ${QEMU_TEST_TEMPLATES}
  export DEVICE_TYPE=${ORIGINAL_DEVICE_TYPE}
fi

# Submit full test run
if [ ! -z "${FULL_TEST_TEMPLATES}" ] && [ ! -z "${FULL_TEST_TEMPLATES}" ]; then
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
fi
