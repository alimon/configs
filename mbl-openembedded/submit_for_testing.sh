#!/bin/bash

# Need different files for each machine
KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "?Image-*-${MACHINE}-*-${BUILD_NUMBER}.bin" | xargs -r basename)
MODULES_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "modules-*-${MACHINE}-*-${BUILD_NUMBER}.tgz" | xargs -r basename)
ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "${IMAGES}-${MACHINE}-*-${BUILD_NUMBER}.rootfs.tar.xz" | xargs -r basename)

# Mapping for MACHINE -> DEVICE_TYPE
case "${MACHINE}" in
  imx7s-warp)
    echo "Skip DEVICE_TYPE for ${MACHINE}"
    DTB_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "?Image-*-${MACHINE}-*-${BUILD_NUMBER}.dtb" | xargs -r basename)
    ;;
  raspberrypi3)
    export DEVICE_TYPE=rpi3-b-32
    RPI_MODEL=bcm2710-rpi-3-b
    DTB_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "?Image-*-${RPI_MODEL}-*-${BUILD_NUMBER}.dtb" | xargs -r basename)
    ;;
esac

export KERNEL_URL=${PUBLISH_SERVER}${PUB_DEST}/${KERNEL_IMG}
export MODULES_URL=${PUBLISH_SERVER}${PUB_DEST}/${MODULES_IMG}
export NFSROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${ROOTFS_TARXZ_IMG}
export DTB_URL=${PUBLISH_SERVER}${PUB_DEST}/${DTB_IMG}

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

# Install jinja2-cli and ruamel.yaml
pip install --user --force-reinstall jinja2-cli ruamel.yaml

[ -z "${DEVICE_TYPE}" ] || \
python configs/openembedded-lkft/submit_for_testing.py \
  --device-type ${DEVICE_TYPE} \
  --build-number ${BUILD_NUMBER} \
  --lava-server ${LAVA_SERVER} \
  --qa-server ${QA_SERVER} \
  --qa-server-team ${QA_SERVER_TEAM} \
  --qa-server-project ${QA_SERVER_PROJECT} \
  --git-commit ${MANIFEST_COMMIT} \
  --template-path configs/mbl-openembedded/lava-job-definitions \
  --template-names template.yaml
