#!/bin/bash

if [ -z "${DRY_RUN}" ]; then
  rm -rf configs
  git clone --depth 1 http://git.linaro.org/ci/job/configs.git

  export CONFIG_PATH=$(realpath configs)

  # Install jinja2-cli and ruamel.yaml, required by submit_for_testing.py
  pip install --user --force-reinstall jinja2-cli ruamel.yaml
else
  export CONFIG_PATH=$(realpath ../)
fi

# main parameters
export DEPLOY_OS=debian
export OS_INFO=debian-${OS_FLAVOUR}
if [ "${DEVICE_TYPE}" = "dragonboard-410c" ] || [ "${DEVICE_TYPE}" = "dragonboard-820c" ] || [ "${DEVICE_TYPE}" = "dragonboard-845c" ]; then
	export QA_SERVER_PROJECT=${DEPLOY_OS}-${DEVICE_TYPE}
else
	echo "Device ${DEVICE_TYPE} not supported for testing"
	exit 0
fi
export BOOT_OS_PROMPT=\'root@linaro-alip:~#\'
export LAVA_JOB_PRIORITY="medium"

# boot and rootfs parameters
export BOOT_URL=${PUBLISH_SERVER}${PUB_DEST}/boot-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.gz
export BOOT_URL_COMP="gz"
export LXC_BOOT_FILE=$(basename ${BOOT_URL} .gz)
export ROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${VENDOR}-${OS_FLAVOUR}-alip-${PLATFORM_NAME}-${BUILD_NUMBER}.img.gz
export ROOTFS_URL_COMP="gz"
export LXC_ROOTFS_FILE=$(basename ${ROOTFS_URL} .gz)

# Tests settings, thermal isn't work well in debian/db410c causes stall
if [ "${DEVICE_TYPE}" = "dragonboard-410c" ]; then
    export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"
    export WLAN_DEVICE="wlan0"
    export WLAN_TIME_DELAY="0s"
    export ETH_DEVICE="eth0"
elif [ "${DEVICE_TYPE}" = "dragonboard-820c" ]; then
    export PM_QA_TESTS="cpufreq cputopology"
    export WLAN_DEVICE="wlp1s0"
    export WLAN_TIME_DELAY="15s"
    export ETH_DEVICE="enP2p1s0"
elif [ "${DEVICE_TYPE}" = "dragonboard-845c" ]; then
    export WLAN_DEVICE="wlan0"
    export WLAN_TIME_DELAY="15s"
    export ETH_DEVICE="enx000ec6817901"
    export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"

    export BOOT_OS_PROMPT=\'root@linaro-gnome:~#\'
    export ROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${VENDOR}-${OS_FLAVOUR}-gnome-${PLATFORM_NAME}-${BUILD_NUMBER}.img.gz
    export LXC_ROOTFS_FILE=$(basename ${ROOTFS_URL} .gz)
else
    export WLAN_DEVICE="wlan0"
    export WLAN_TIME_DELAY="0s"
    export ETH_DEVICE="eth0"
    export PM_QA_TESTS="cpufreq cpuidle cpuhotplug thermal cputopology"
fi
export SMOKE_TESTS="pwd, lsb_release -a, uname -a, ip a, lscpu, vmstat, lsblk"

LAVA_TEMPLATE_PATH=${CONFIG_PATH}/lt-qcom/lava-job-definitions
cd ${LAVA_TEMPLATE_PATH}

python ${CONFIG_PATH}/openembedded-lkft/submit_for_testing.py \
    --device-type ${DEVICE_TYPE} \
    --build-number ${BUILD_NUMBER} \
    --lava-server ${LAVA_SERVER} \
    --qa-server ${QA_SERVER} \
    --qa-server-team qcomlt \
    --qa-server-project ${QA_SERVER_PROJECT} \
    --git-commit ${BUILD_NUMBER} \
    --template-path "${LAVA_TEMPLATE_PATH}" \
    --testplan-path "${LAVA_TEMPLATE_PATH}" \
    ${DRY_RUN} \
    --test-plan testplan/main.yaml testplan/wifi.yaml testplan/bt.yaml

# Submit to PMWG Lava server because it has special hw to do energy probes
python ${CONFIG_PATH}/openembedded-lkft/submit_for_testing.py \
    --device-type ${DEVICE_TYPE} \
    --build-number ${BUILD_NUMBER} \
    --lava-server ${PMWG_LAVA_SERVER} \
    --qa-server ${QA_SERVER} \
    --qa-server-team qcomlt \
    --qa-server-project ${QA_SERVER_PROJECT} \
    --git-commit ${BUILD_NUMBER} \
    --template-path "${LAVA_TEMPLATE_PATH}" \
    --testplan-path "${LAVA_TEMPLATE_PATH}" \
    ${DRY_RUN} \
    --test-plan testplan/pmwg.yaml
