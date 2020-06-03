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
export DEPLOY_OS=oe
export OS_INFO=openembedded-${DISTRO}-${MANIFEST_BRANCH}

# boot and rootfs parameters, BOOT_URL comes from builders.sh
# and has not compression
export BOOT_URL_COMP=
export LXC_BOOT_FILE=$(basename ${BOOT_URL})

export LAVA_JOB_PRIORITY="medium"

case "${MACHINE}" in
  dragonboard-410c|dragonboard-820c|dragonboard-845c)
    export DEVICE_TYPE="${MACHINE}"

    # Tests settings, thermal fails in db410c
    export IGNORE_TESTS_REPO="https://git.linaro.org/landing-teams/working/qualcomm/configs.git"
    export GST_IGNORE_TESTS_REPO=${IGNORE_TESTS_REPO}
    export PIGLIT_IGNORE_TESTS_REPO=${IGNORE_TESTS_REPO}
    if [ ${DEVICE_TYPE} = "dragonboard-410c" ]; then
      export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"
      export WLAN_DEVICE="wlan0"
      export WLAN_TIME_DELAY="0s"
      export ETH_DEVICE="eth0"
      export GST_IGNORE_TESTS_FILE="qa/gst-validate/db410c.ignore"
      export PIGLIT_IGNORE_TESTS_FILE="qa/piglit/db410c.ignore"

      export BOOT_OS_PROMPT=\'root@dragonboard-410c:~#\'
    elif [ ${DEVICE_TYPE} = "dragonboard-820c" ]; then
      export PM_QA_TESTS="cpufreq cputopology"
      export WLAN_DEVICE="wlp1s0"
      export WLAN_TIME_DELAY="15s"
      export ETH_DEVICE="enP2p1s0"
      export GST_IGNORE_TESTS_FILE="qa/gst-validate/db820c.ignore"
      export PIGLIT_IGNORE_TESTS_FILE="qa/piglit/db820c.ignore"

      export BOOT_OS_PROMPT=\'root@dragonboard-820c:~#\'
    elif [ ${DEVICE_TYPE} = "dragonboard-845c" ]; then
      export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"
      export WLAN_DEVICE="wlan0"
      export WLAN_TIME_DELAY="15s"
      export ETH_DEVICE="enp1s0u3"
      export GST_IGNORE_TESTS_FILE="qa/gst-validate/db410c.ignore"
      export PIGLIT_IGNORE_TESTS_FILE="qa/piglit/db410c.ignore"

      export BOOT_OS_PROMPT=\'root@dragonboard-845c:~#\'
    fi
    export SMOKE_TESTS="pwd, uname -a, ip a, vmstat, lsblk"
    export PTEST_EXCLUDE="bluez5 libxml2 parted python strace"

    case "${DISTRO}" in
      rpb)
        export ROOTFS_URL=${ROOTFS_SPARSE_BUILD_URL}
        export ROOTFS_URL_COMP="gz"
        export LXC_ROOTFS_FILE=$(basename ${ROOTFS_URL} .gz)

	LAVA_TEMPLATE_PATH=${CONFIG_PATH}/lt-qcom/lava-job-definitions
	cd ${LAVA_TEMPLATE_PATH}
        python ${CONFIG_PATH}/openembedded-lkft/submit_for_testing.py \
            --device-type ${DEVICE_TYPE} \
            --build-number ${BUILD_NUMBER} \
            --lava-server ${LAVA_SERVER} \
            --qa-server ${QA_SERVER} \
            --qa-server-team qcomlt \
            --qa-server-project openembedded-rpb-${MANIFEST_BRANCH} \
            --env-suffix="-${DISTRO}" \
            --git-commit ${BUILD_NUMBER} \
	    --template-path "${LAVA_TEMPLATE_PATH}" \
	    --testplan-path "${LAVA_TEMPLATE_PATH}" \
	    ${DRY_RUN} \
            --test-plan testplan/main.yaml testplan/wifi.yaml testplan/bt.yaml
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
