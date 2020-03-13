#!/bin/bash -e
config_url="https://android-git.linaro.org/android-build-configs.git/plain/lkft/${build_config}?h=lkft"
wget ${config_url} -O ${build_config}
source ${build_config}
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
