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
export RESIZE_ROOTFS=True

SEND_TESTJOB=false

case "${MACHINE}" in
  dragonboard410c|dragonboard820c|sdm845_mtp)
    SEND_TESTJOB=true

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

      if [ ${QA_SERVER_PROJECT} = "linux-master" ]; then
        SEND_TESTJOB=false
      fi
    elif [ ${MACHINE} = "sdm845_mtp" ]; then
      export LAVA_DEVICE_TYPE="sdm845-mtp"
      export INSTALL_FASTBOOT=

      export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"
      export WLAN_DEVICE="wlan0"
      export WLAN_TIME_DELAY="0s"
      export ETH_DEVICE="eth0"

      # XXX: We are using db410c OE userspace
      export BOOT_OS_PROMPT=\'root@dragonboard-410c:~#\'

      if [ ${QA_SERVER_PROJECT} = "linux-master" ]; then
        SEND_TESTJOB=false
      fi
    fi
    export SMOKE_TESTS="pwd, uname -a, ip a, vmstat, lsblk"
    ;;
  *)
    echo "Skip LAVA_DEVICE_TYPE for ${MACHINE}"
    ;;
esac

if [ $SEND_TESTJOB = true ]; then
  # Get KernelCI information for repo, branch and commit, enable ex to don't exit if fails and to hide the token.
  set +ex
  if [ ${QA_SERVER_PROJECT} = "linux-master" ]; then
    KERNELCI_JSON="$(curl -s -H "Authorization: ${QCOMLT_KERNELCI_TOKEN}" "https://api.kernelci.org/job?job=mainline&git_branch=master&kernel=${KERNEL_VERSION}")"
  elif [ ${QA_SERVER_PROJECT} = "linux-integration" ]; then
    KERNELCI_JSON="$(curl -s -H "Authorization: ${QCOMLT_KERNELCI_TOKEN}" "https://api.kernelci.org/job?job=qcom-lt&git_branch=integration-linux-qcomlt&kernel=${KERNEL_VERSION}")"
  fi
  set -x

  export KERNEL_REPO="$(echo "${KERNELCI_JSON}" | python -c "import sys, json; print json.load(sys.stdin)['result'][0]['git_url']")"
  export KERNEL_BRANCH="$(echo "${KERNELCI_JSON}" | python -c "import sys, json; print json.load(sys.stdin)['result'][0]['git_branch']")"
  export KERNEL_COMMIT="$(echo "${KERNELCI_JSON}" | python -c "import sys, json; print json.load(sys.stdin)['result'][0]['git_commit']")"
  set -e

  python configs/openembedded-lkft/submit_for_testing.py \
      --device-type ${LAVA_DEVICE_TYPE} \
      --build-number ${BUILD_NUMBER} \
      --lava-server ${LAVA_SERVER} \
      --qa-server ${QA_SERVER} \
      --qa-server-team qcomlt \
      --qa-server-project ${QA_SERVER_PROJECT} \
      --git-commit ${BUILD_NUMBER} \
      --template-path configs/lt-qcom-linux-integration/lava-job-definitions \
      --template-names template-bootrr.yaml

  python configs/openembedded-lkft/submit_for_testing.py \
      --device-type ${LAVA_DEVICE_TYPE} \
      --build-number ${BUILD_NUMBER} \
      --lava-server ${LAVA_SERVER} \
      --qa-server ${QA_SERVER} \
      --qa-server-team qcomlt \
      --qa-server-project ${QA_SERVER_PROJECT} \
      --git-commit ${BUILD_NUMBER} \
      --template-path configs/lt-qcom-linux-integration/lava-job-definitions \
      --template-base-pre base_template-functional.yaml \
      --template-names template-functional.yaml
fi
