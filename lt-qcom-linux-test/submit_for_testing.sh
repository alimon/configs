#!/bin/bash

set -ex

if [ -z "${DRY_RUN}" ]; then
  rm -rf configs
  git clone --depth 1 http://git.linaro.org/ci/job/configs.git
  export CONFIG_PATH=$(realpath configs)

  # Install jinja2-cli and ruamel.yaml, required by submit_for_testing.py
  pip install --user --force-reinstall jinja2-cli ruamel.yaml
else
  export CONFIG_PATH=$(realpath ../)
fi

SEND_TESTJOB=false

case "${MACHINE}" in
  apq8016-sbc|apq8096-db820c|sdm845-mtp|qcs404-evb-1000|qcs404-evb-4000)
    SEND_TESTJOB=true

    if [ ${MACHINE} = "apq8016-sbc" ]; then
      export LAVA_DEVICE_TYPE="dragonboard-410c"

      export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"
      export WLAN_DEVICE="wlan0"
      export WLAN_TIME_DELAY="0s"
      export ETH_DEVICE="eth0"

    elif [ ${MACHINE} = "apq8096-db820c" ]; then
      export LAVA_DEVICE_TYPE="dragonboard-820c"

      export PM_QA_TESTS="cpufreq cputopology"
      export WLAN_DEVICE="wlp1s0"
      export WLAN_TIME_DELAY="15s"
      export ETH_DEVICE="enP2p1s0"

    elif [ ${MACHINE} = "sdm845-mtp" ]; then
      export LAVA_DEVICE_TYPE="sdm845-mtp"

      export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"
      export WLAN_DEVICE="wlan0"
      export WLAN_TIME_DELAY="0s"
      export ETH_DEVICE="eth0"
    elif [ ${MACHINE} = "qcs404-evb-1000" ]; then
      export LAVA_DEVICE_TYPE="qcs404-evb-1k"

      export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"
      export WLAN_DEVICE="wlan0"
      export WLAN_TIME_DELAY="0s"
      export ETH_DEVICE="eth0"

      if [ ${QA_SERVER_PROJECT} = "linux-master" ]; then
        SEND_TESTJOB=false
      fi
    elif [ ${MACHINE} = "qcs404-evb-4000" ]; then
      export LAVA_DEVICE_TYPE="qcs404-evb-4k"

      export PM_QA_TESTS="cpufreq cpuidle cpuhotplug cputopology"
      export WLAN_DEVICE="wlan0"
      export WLAN_TIME_DELAY="0s"
      export ETH_DEVICE="eth0"

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
    export KERNEL_TREE="mainline"
  elif [ ${QA_SERVER_PROJECT} = "linux-integration" ]; then
    KERNELCI_JSON="$(curl -s -H "Authorization: ${QCOMLT_KERNELCI_TOKEN}" "https://api.kernelci.org/job?job=qcom-lt&git_branch=integration-linux-qcomlt&kernel=${KERNEL_VERSION}")"
    export KERNEL_TREE="qcom-lt"
  elif [[ ${QA_SERVER_PROJECT} == *"linux-release"* ]]; then
    export KERNEL_TREE="qcom-lt"
    export KERNELCI_JSON=""
  fi
  set -x

  export KERNEL_REPO="$(echo "${KERNELCI_JSON}" | python -c "import sys, json; print json.load(sys.stdin)['result'][0]['git_url']")"
  export KERNEL_BRANCH="$(echo "${KERNELCI_JSON}" | python -c "import sys, json; print json.load(sys.stdin)['result'][0]['git_branch']")"
  export KERNEL_COMMIT="$(echo "${KERNELCI_JSON}" | python -c "import sys, json; print json.load(sys.stdin)['result'][0]['git_commit']")"
  set -e

  LAVA_TEMPLATE_PATH=${CONFIG_PATH}/lt-qcom/lava-job-definitions
  cd ${LAVA_TEMPLATE_PATH}

  export DEPLOY_OS=oe

  export LAVA_JOB_PRIORITY="high"
  export BOOT_URL=${PUBLISH_SERVER}${PUB_DEST}/${BOOT_FILE}
  export BOOT_URL_COMP=
  export LXC_BOOT_FILE=$(basename ${BOOT_URL})
  python ${CONFIG_PATH}/openembedded-lkft/submit_for_testing.py \
      --device-type ${LAVA_DEVICE_TYPE} \
      --build-number ${BUILD_NUMBER} \
      --lava-server ${LAVA_SERVER} \
      --qa-server ${QA_SERVER} \
      --qa-server-team qcomlt \
      --qa-server-project ${QA_SERVER_PROJECT} \
      --git-commit ${BUILD_NUMBER} \
      --template-path "${LAVA_TEMPLATE_PATH}" \
      --testplan-path "${LAVA_TEMPLATE_PATH}" \
      ${DRY_RUN} \
      --test-plan testplan/kernel-bootrr.yaml

  export LAVA_JOB_PRIORITY="medium"
  export BOOT_URL=${PUBLISH_SERVER}${PUB_DEST}/${BOOT_ROOTFS_FILE}
  export BOOT_URL_COMP=
  export LXC_BOOT_FILE=$(basename ${BOOT_URL})
  export ROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${ROOTFS_FILE}
  export ROOTFS_URL_COMP="gz"
  export LXC_ROOTFS_FILE=$(basename ${ROOTFS_URL} .gz)
  python ${CONFIG_PATH}/openembedded-lkft/submit_for_testing.py \
      --device-type ${LAVA_DEVICE_TYPE} \
      --build-number ${BUILD_NUMBER} \
      --lava-server ${LAVA_SERVER} \
      --qa-server ${QA_SERVER} \
      --qa-server-team qcomlt \
      --qa-server-project ${QA_SERVER_PROJECT} \
      --git-commit ${BUILD_NUMBER} \
      --template-path "${LAVA_TEMPLATE_PATH}" \
      --testplan-path "${LAVA_TEMPLATE_PATH}" \
      ${DRY_RUN} \
      --test-plan testplan/kernel-functional.yaml
fi
