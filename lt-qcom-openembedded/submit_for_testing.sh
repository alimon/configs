#!/bin/bash

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

# main parameters
export DEPLOY_OS=oe
export OS_INFO=openembedded-${DISTRO}-${MANIFEST_BRANCH}
export BOOT_OS_PROMPT=\'root@dragonboard-410c:~#\'

# boot and rootfs parameters, BOOT_URL comes from builders.sh
# and has not compression
export BOOT_URL_COMP=
export LXC_BOOT_FILE=$(basename ${BOOT_URL})

export RESIZE_ROOTFS=

case "${MACHINE}" in
  dragonboard-410c)
    export DEVICE_TYPE="${MACHINE}"
    case "${DISTRO}" in
      rpb)
        export ROOTFS_URL=${ROOTFS_SPARSE_BUILD_URL}
        export ROOTFS_URL_COMP="gz"
        export LXC_ROOTFS_FILE=$(basename ${ROOTFS_URL} .gz)
        python configs/openembedded-lkft/submit_for_testing.py \
            --device-type ${DEVICE_TYPE} \
            --build-number ${BUILD_NUMBER} \
            --lava-server ${LAVA_SERVER} \
            --qa-server ${QA_SERVER} \
            --qa-server-team qcomlt \
            --qa-server-project openembedded-rpb-${MANIFEST_BRANCH} \
            --env-suffix="-${DISTRO}" \
            --git-commit ${BUILD_NUMBER} \
            --template-path configs/lt-qcom/lava-job-definitions \
            --template-base-pre base_template.yaml \
            --template-names template.yaml template-wifi.yaml template-bt.yaml template-ptest.yaml

        export ROOTFS_URL=${ROOTFS_DESKTOP_SPARSE_BUILD_URL}
        export ROOTFS_URL_COMP="gz"
        export LXC_ROOTFS_FILE=$(basename ${ROOTFS_URL} .gz)
        python configs/openembedded-lkft/submit_for_testing.py \
            --device-type ${DEVICE_TYPE} \
            --build-number ${BUILD_NUMBER} \
            --lava-server ${LAVA_SERVER} \
            --qa-server ${QA_SERVER} \
            --qa-server-team qcomlt \
            --qa-server-project openembedded-rpb-${MANIFEST_BRANCH} \
            --env-suffix="-${DISTRO}" \
            --git-commit ${BUILD_NUMBER} \
            --template-path configs/lt-qcom/lava-job-definitions \
            --template-base-pre base_template.yaml \
            --template-names template-desktop.yaml
      ;;
      rpb-wayland)
        echo "Currently no tests for rpb-wayland"
      ;;
    esac
    ;;
  *)
    echo "Skip DEVICE_TYPE for ${MACHINE}"
    ;;
esac
