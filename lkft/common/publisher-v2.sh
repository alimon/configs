#!/bin/bash -ex

# LKFT_WORK_DIR set in lkft/common/builders-v2.sh does not work here
# the value is empty, so needs to set it again
export LKFT_WORK_DIR=/home/buildslave/srv/${BUILD_DIR}/workspace
cd ${LKFT_WORK_DIR}

JOB_OUT_PUBLISH=out/publish
rm -fr ${JOB_OUT_PUBLISH} && mkdir -p ${JOB_OUT_PUBLISH}
url_build_info="https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/hikey/build-info/aosp-master-template.txt"
if [ -n "${SNAPSHOT_SITE_BUILD_INFO_URL}" ]; then
    url_build_info=${SNAPSHOT_SITE_BUILD_INFO_URL}
fi
wget ${url_build_info} -O ${JOB_OUT_PUBLISH}/BUILD-INFO.txt

PUBLISH_COMMON_FILES="pinned-manifest.xml defconfig gki_defconfig upstream_gki_defconfig SHA256SUMS.txt"
for build_config in ${ANDROID_BUILD_CONFIG}; do
    # the config file should be in the directory of android-build-configs/lkft
    # or copied to there by the linaro-lkft.sh build
    source ${LKFT_WORK_DIR}/android-build-configs/lkft/${build_config}

    for f in ${PUBLISH_COMMON_FILES} ${PUBLISH_FILES}; do
        if [ -f out/${build_config}/${f} ]; then
            mv -v out/${build_config}/${f} ${JOB_OUT_PUBLISH}/${build_config}-${f}
        fi
    done
done

# Publish
PUB_DEST="android/lkft/${JOB_NAME}/${BUILD_NUMBER}"
if [ -n "${SNAPAHOT_SITE_ROOT}" ]; then
    PUB_DEST="${SNAPAHOT_SITE_ROOT}/${JOB_NAME}/${BUILD_NUMBER}"
fi
HOST_BIN=out/host/bin
mkdir -p ${HOST_BIN}
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOST_BIN}/linaro-cp.py
time python3 ${HOST_BIN}/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  ${JOB_OUT_PUBLISH} ${PUB_DEST}
