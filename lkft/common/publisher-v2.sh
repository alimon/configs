#!/bin/bash -ex

cd /home/buildslave/srv/${BUILD_DIR}

JOB_OUT_PUBLISH=out/publish
rm -fr ${JOB_OUT_PUBLISH} && mkdir -p ${JOB_OUT_PUBLISH}
url_build_info="https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/hikey/build-info/aosp-master-template.txt"
wget -q ${url_build_info} -O ${JOB_OUT_PUBLISH}/BUILD-INFO.txt

PUBLISH_COMMON_FILES="pinned-manifest.xml defconfig SHA256SUMS.txt"
for build_config in ${ANDROID_BUILD_CONFIG}; do
    config_url="https://android-git.linaro.org/android-build-configs.git/plain/lkft/${build_config}?h=lkft"
    wget ${config_url} -O ${build_config}
    source ${build_config}

    for f in ${PUBLISH_COMMON_FILES} ${PUBLISH_FILES}; do
        mv -v out/${ANDROID_BUILD_CONFIG}/${f} ${JOB_OUT_PUBLISH}/${build_config}-${f}
    done
done

# Publish
PUB_DEST=android/lkft/${JOB_NAME}/${BUILD_NUMBER}
HOST_BIN=out/host/bin
mkdir -p ${HOST_BIN}
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOST_BIN}/linaro-cp.py
time python ${HOST_BIN}/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  ${JOB_OUT_PUBLISH} ${PUB_DEST}
