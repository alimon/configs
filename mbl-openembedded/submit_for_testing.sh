#!/bin/bash

# Need different files for each machine
KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "?Image-*-${MACHINE}-*-${BUILD_NUMBER}.bin" | xargs -r basename)
MODULES_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "modules-*-${MACHINE}-*-${BUILD_NUMBER}.tgz" | xargs -r basename)
ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.tar.xz" | xargs -r basename)

# Mapping for MACHINE -> DEVICE_TYPE
case "${MACHINE}" in
  imx7s-warp)
    echo "Skip DEVICE_TYPE for ${MACHINE}"
    DTB_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "?Image-*-${MACHINE}-*-${BUILD_NUMBER}.dtb" | xargs -r basename)
    ;;
  raspberrypi3)
    DEVICE_TYPE=rpi3-b-32
    RPI_MODEL=bcm2710-rpi-3-b
    DTB_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "?Image-*-${RPI_MODEL}-*-${BUILD_NUMBER}.dtb" | xargs -r basename)
    ;;
esac

KERNEL_URL=${PUBLISH_SERVER}${PUB_DEST}/${KERNEL_IMG}
MODULES_URL=${PUBLISH_SERVER}${PUB_DEST}/${MODULES_IMG}
NFSROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${ROOTFS_TARXZ_IMG}
DTB_URL=${PUBLISH_SERVER}${PUB_DEST}/${DTB_IMG}

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

[ -z "${DEVICE_TYPE}" ] || \
sed -e "s|\${BUILD_NUMBER}|${BUILD_NUMBER}|" \
    -e "s|\${KERNEL_URL}|${KERNEL_URL}|" \
    -e "s|\${MODULES_URL}|${MODULES_URL}|" \
    -e "s|\${NFSROOTFS_URL}|${NFSROOTFS_URL}|" \
    -e "s|\${DTB_URL}|${DTB_URL}|" \
    -e "s|\${MACHINE}|${MACHINE}|" \
    -e "s|\${MANIFEST_BRANCH}|${MANIFEST_BRANCH}|" \
    -e "s|\${BUILD_URL}|${BUILD_URL}|" \
    -e "s|\${PUBLISH_SERVER}|${PUBLISH_SERVER}|" \
    -e "s|\${PUB_DEST}|${PUB_DEST}|" \
    < configs/mbl-openembedded/lava-job-definitions/${DEVICE_TYPE}/template.yaml \
    > ${WORKSPACE}/custom_lava_job_definition.yaml

cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEVICE_TYPE=${DEVICE_TYPE}
CUSTOM_YAML_URL=${JOB_URL}/ws/custom_lava_job_definition.yaml
LAVA_SERVER=${LAVA_SERVER}
EOF
