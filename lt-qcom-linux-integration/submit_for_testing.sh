#!/bin/bash

set -ex

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

# Install jinja2-cli and ruamel.yaml, required by submit_for_testing.py
pip install --user --force-reinstall jinja2-cli ruamel.yaml

export BOOT_URL=${PUBLISH_SERVER}${PUB_DEST}/${BOOT_FILE}
export BOOT_URL_COMP=
export LXC_BOOT_FILE=$(basename ${BOOT_URL})

export BOOT_ROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${BOOT_ROOTFS_FILE}
export BOOT_ROOTFS_URL_COMP=
export LXC_BOOT_ROOTFS_FILE=$(basename ${BOOT_ROOTFS_URL})
export ROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${ROOTFS_FILE}
export ROOTFS_URL_COMP="gz"
export LXC_ROOTFS_FILE=$(basename ${ROOTFS_URL} .gz)

case "${MACHINE}" in
  dragonboard410c|dragonboard820c|sdm845_mtp)
    if [ ${MACHINE} = "dragonboard410c" ]; then
      export LAVA_DEVICE_TYPE="dragonboard-410c"
      export INSTALL_FASTBOOT=True

      export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"
      export WLAN_DEVICE="wlan0"
      export WLAN_TIME_DELAY="0s"
      export ETH_DEVICE="eth0"

      export BOOT_OS_PROMPT=\'root@dragonboard-410c:~#\'
    elif [ ${MACHINE} = "dragonboard820c" ]; then
      export LAVA_DEVICE_TYPE="dragonboard-820c"
      export INSTALL_FASTBOOT=True

      export PM_QA_TESTS="cpufreq cputopology"
      export WLAN_DEVICE="wlp1s0"
      export WLAN_TIME_DELAY="15s"
      export ETH_DEVICE="enP2p1s0"

      export BOOT_OS_PROMPT=\'root@dragonboard-820c:~#\'
    elif [ ${MACHINE} = "sdm845_mtp" ]; then
      export LAVA_DEVICE_TYPE="sdm845-mtp"
      export INSTALL_FASTBOOT=
      export LAVA_SERVER="${LKFT_STAGING_LAVA_SERVER}"

      export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"
      export WLAN_DEVICE="wlan0"
      export WLAN_TIME_DELAY="0s"
      export ETH_DEVICE="eth0"

      # XXX: We are using db410c OE userspace
      export BOOT_OS_PROMPT=\'root@dragonboard-410c:~#\'
    fi
    export SMOKE_TESTS="pwd, uname -a, ip a, vmstat, lsblk"

    python configs/openembedded-lkft/submit_for_testing.py \
        --device-type ${LAVA_DEVICE_TYPE} \
        --build-number ${BUILD_NUMBER} \
        --lava-server ${LAVA_SERVER} \
        --qa-server ${QA_SERVER} \
        --qa-server-team qcomlt \
        --qa-server-project linux-integration \
        --git-commit ${BUILD_NUMBER} \
        --template-path configs/lt-qcom-linux-integration/lava-job-definitions \
        --template-names template-bootrr.yaml

    python configs/openembedded-lkft/submit_for_testing.py \
        --device-type ${LAVA_DEVICE_TYPE} \
        --build-number ${BUILD_NUMBER} \
        --lava-server ${LAVA_SERVER} \
        --qa-server ${QA_SERVER} \
        --qa-server-team qcomlt \
        --qa-server-project linux-integration \
        --git-commit ${BUILD_NUMBER} \
        --template-path configs/lt-qcom-linux-integration/lava-job-definitions \
        --template-base-pre base_template-functional.yaml \
        --template-names template-functional.yaml
    ;;
  *)
    echo "Skip LAVA_DEVICE_TYPE for ${MACHINE}"
    ;;
esac
