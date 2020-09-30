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
  apq8016-sbc|apq8096-db820c|sdm845-mtp|sdm845-db845c|qcs404-evb-4000)
    SEND_TESTJOB=true

    export SMOKE_TESTS="pwd, uname -a, ip a, vmstat, lsblk, lscpu"
    export WLAN_DEVICE="wlan0"
    export ETH_DEVICE="eth0"

    if [ ${MACHINE} = "apq8016-sbc" ]; then
      export LAVA_DEVICE_TYPE="dragonboard-410c"
      export DEQP_FAIL_LIST="deqp-freedreno-a307-fails.txt"
    elif [ ${MACHINE} = "apq8096-db820c" ]; then
      export LAVA_DEVICE_TYPE="dragonboard-820c"
      export DEQP_FAIL_LIST="deqp-freedreno-a530-fails.txt"
    elif [ ${MACHINE} = "sdm845-db845c" ]; then
      export LAVA_DEVICE_TYPE="dragonboard-845c"
      export DEQP_FAIL_LIST="deqp-freedreno-a630-fails.txt"
    elif [ ${MACHINE} = "sdm845-mtp" ]; then
      export LAVA_DEVICE_TYPE="sdm845-mtp"
    elif [ ${MACHINE} = "qcs404-evb-4000" ]; then
      export LAVA_DEVICE_TYPE="qcs404-evb-4k"
    fi
    ;;
  *)
    echo "Skip LAVA_DEVICE_TYPE for ${MACHINE}"
    ;;
esac

# Select which testplans will be send to LAVA
# - bootrr on integration, mainline and release.
# - smoke on integration, mainline and release with Dragonboard machines.
case "${MACHINE}" in
  apq8016-sbc|apq8096-db820c|sdm845-db845c)
      SMOKE_TEST_PLAN=true
      DESKTOP_TEST_PLAN=true
      MULTIMEDIA_TEST_PLAN=true
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

  if [ $SMOKE_TEST_PLAN = true ]; then
    export LAVA_JOB_PRIORITY="medium"
    export BOOT_URL=${PUBLISH_SERVER}${PUB_DEST}/${BOOT_ROOTFS_FILE}
    export BOOT_URL_COMP=
    export LXC_BOOT_FILE=$(basename ${BOOT_URL})
    export ROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${ROOTFS_FILE}
    export ROOTFS_URL_COMP="gz"
    export LXC_ROOTFS_FILE=$(basename ${ROOTFS_FILE} .gz)
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
        --test-plan testplan/kernel-smoke.yaml
  fi

  if [ $DESKTOP_TEST_PLAN = true ]; then
    export LAVA_JOB_PRIORITY="medium"
    export BOOT_URL=${PUBLISH_SERVER}${PUB_DEST}/${BOOT_ROOTFS_FILE}
    export BOOT_URL_COMP=
    export LXC_BOOT_FILE=$(basename ${BOOT_URL})
    export ROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${ROOTFS_DESKTOP_FILE}
    export ROOTFS_URL_COMP="gz"
    export LXC_ROOTFS_FILE=$(basename ${ROOTFS_DESKTOP_FILE} .gz)
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
        --test-plan testplan/kernel-desktop.yaml
  fi

  if [ $MULTIMEDIA_TEST_PLAN = true ]; then
    export LAVA_JOB_PRIORITY="medium"
    export BOOT_URL=${PUBLISH_SERVER}${PUB_DEST}/${BOOT_ROOTFS_FILE}
    export BOOT_URL_COMP=
    export LXC_BOOT_FILE=$(basename ${BOOT_URL})
    export ROOTFS_URL=${PUBLISH_SERVER}${PUB_DEST}/${ROOTFS_DESKTOP_FILE}
    export ROOTFS_URL_COMP="gz"
    export LXC_ROOTFS_FILE=$(basename ${ROOTFS_DESKTOP_FILE} .gz)
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
        --test-plan testplan/kernel-multimedia.yaml
  fi
fi
