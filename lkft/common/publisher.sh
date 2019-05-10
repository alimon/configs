#!/bin/bash -ex

config_url="https://android-git.linaro.org/android-build-configs.git/plain/lkft/${ANDROID_BUILD_CONFIG}?h=lkft"
wget ${config_url} -O ${ANDROID_BUILD_CONFIG}
source ${ANDROID_BUILD_CONFIG}

JOB_OUT_PUBLISH=out/${ANDROID_BUILD_CONFIG}/publish
wget -q https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/hikey/build-info/aosp-master-template.txt -O ${JOB_OUT_PUBLISH}/BUILD-INFO.txt

PUBLISH_COMMON_FILES="pinned-manifest.xml defconfig SHA256SUMS.txt"
for f in ${PUBLISH_COMMON_FILES} ${PUBLISH_FILES}; do
    mv -v out/${ANDROID_BUILD_CONFIG}/${f} ${JOB_OUT_PUBLISH}/${f}
done

# Publish
PUB_DEST=android/lkft/${JOB_NAME}/${BUILD_NUMBER}
mkdir -p ${PWD}/out/host/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O out/host/bin/linaro-cp.py
time python out/host/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  ${JOB_OUT_PUBLISH} ${PUB_DEST}