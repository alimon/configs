#!/bin/bash

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

# Used by DB410C's template:
export RESIZE_ROOTFS=${RESIZE_ROOTFS:-}
export DISK_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "${IMAGES}-${MACHINE}-*-${BUILD_NUMBER}.rootfs.wic.gz" | xargs -r basename)
export IMAGE_URL=${PUBLISH_SERVER}${PUB_DEST}/${DISK_IMG}

[ -z "${DEVICE_TYPE}" ] || \
python configs/openembedded-lkft/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --build-number ${BUILD_NUMBER} \
  --lava-server ${LAVA_SERVER} \
  --qa-server ${QA_SERVER} \
  --qa-server-team ${QA_SERVER_TEAM} \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${MANIFEST_COMMIT} \
  --template-path configs/warp7-openembedded/lava-job-definitions/ \
  --template-names template-boot.yaml
