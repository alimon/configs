#!/bin/bash -x

if [ -n "${1}" ] && [ -f "${1}" ]; then
    source ${1}
fi
# call api of android.linaro.org for lkft report check scheduling
if [ -n "${KERNEL_BRANCH}" ] && \
    [ -n "${QA_BUILD_VERSION}" ] && \
    [ -n "${CALLER_JOB_NAME}" ] && \
    [ -n "${CALLER_BUILD_NUMBER}" ]; then
    curl -L https://android.linaro.org/lkft/newchanges/${KERNEL_BRANCH}/${QA_BUILD_VERSION}/${CALLER_JOB_NAME}/${CALLER_BUILD_NUMBER} || true
fi

