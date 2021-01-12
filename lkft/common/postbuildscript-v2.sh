#!/bin/bash -e
export LKFT_WORK_DIR=${LKFT_WORK_DIR:-"/home/buildslave/srv/${BUILD_DIR}/workspace"}

for build_config in ${ANDROID_BUILD_CONFIG}; do
    # the config file should be in the directory of android-build-configs/lkft
    # or copied to there by the linaro-lkft.sh build
    source ${LKFT_WORK_DIR}/android-build-configs/lkft/${build_config}

    KERNEL_COMMIT=${SRCREV_kernel}
    if [ -n "${MAKE_KERNELVERSION}" ] && echo "X${USE_KERNELVERSION_FOR_QA_BUILD_VERSION}" | grep -i "Xtrue"; then
        QA_BUILD_VERSION=${MAKE_KERNELVERSION}-${KERNEL_COMMIT:0:12}
    elif [ ! -z "${KERNEL_DESCRIBE}" ]; then
        QA_BUILD_VERSION=${KERNEL_DESCRIBE}
    else
        QA_BUILD_VERSION=${KERNEL_COMMIT:0:12}
    fi

    if [ -z "${TEST_QA_SERVER_TEAM}" ]; then
        TEST_QA_SERVER_TEAM="android-lkft"
    fi
    curl --header "Auth-Token: ${QA_REPORTS_TOKEN}" --form tests='{"build_process/build": "fail"}'  ${qa_server}/api/submit/${qa_server_team}/${qa_server_project}/${QA_BUILD_VERSION}/${TEST_DEVICE_TYPE}
done
