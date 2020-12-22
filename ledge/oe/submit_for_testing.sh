#!/bin/bash

# Install all deps required for lauch lava jobs
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
     echo "INFO: apt update error - try again in a moment"
     sleep 15
     sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi

pkg_list="chrpath cpio diffstat gawk git expect pkg-config python-pip python-requests python-crypto libpixman-1-dev python python3 python-all-dev python-wheel"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
     echo "INFO: apt install error - try again in a moment"
     sleep 15
     sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

sudo locale-gen en_US.UTF-8 && sudo update-locale LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# install required python modules
pip install --user --force-reinstall Jinja2 ruamel.yaml


if [ ${MACHINE} = "ledge-ti-am572x" ]; then
       export MACHINE="x15-bl_uefi"
fi

[ -z "${KSELFTEST_PATH}" ] && export KSELFTEST_PATH="/opt/kselftests/mainline/"
[ -z "${LAVA_JOB_PRIORITY}" ] && export LAVA_JOB_PRIORITY="25"
[ -z "${SANITY_LAVA_JOB_PRIORITY}" ] && export SANITY_LAVA_JOB_PRIORITY="30"
[ -z "${SKIP_LAVA}" ] || unset DEVICE_TYPE
[ -z "${QA_SERVER_TEAM}" ] && export QA_SERVER_TEAM=rpb
[ -z "${TOOLCHAIN}" ] && export TOOLCHAIN="unknown"
[ -z "${TDEFINITIONS_REVISION}" ] && export TDEFINITIONS_REVISION="kselftest-5.1"
[ -z "${MANIFEST_COMMIT}" ] && export MANIFEST_COMMIT="HEAD"
[ -z "${MANIFEST_BRANCH}" ] && export MANIFEST_BRANCH="unknown"

# Used by DB410C's template:
export RESIZE_ROOTFS=${RESIZE_ROOTFS:-}

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

if [ -n "${DEBIAN}" ]; then
	sed -i 's/job_name:.*RPB OE/job_name: LEDGE RPB Debian ${MACHINE}/' configs/rpb-openembedded/lava-job-definitions/*/template-boot.yaml 
fi

if [ -z "${DEVICE_TYPE}" ]; then
    if [ "${MACHINE}" = "ledge-multi-armv7" ]; then
        #DEVICE_TYPE="qemuarmuefi stm32mp157c-dk2 x15-bl_uefi"
        DEVICE_TYPE="qemuarmuefi qemuarm_atf_fip"
    elif [ "${MACHINE}" = "ledge-multi-armv8" ]; then
        DEVICE_TYPE="qemuarm64uefi  synquacer qemuarm64_atf_fip"
    fi
fi

function oe_urls {
      if [ "${MACHINE}" = "ledge-multi-armv7" ]; then
         if [ "${DEVICE_TYPE}" = "x15-bl_uefi"; then
             export SYSTEM_URL=`echo ${SYSTEM_URL} | sed  "s/ledge-qemuarm/ledge-ti-am572x/"`
         fi
             export FIRMWARE_URL=`echo ${SYSTEM_URL} | sed -e "s|ledge-qemuarm.*|ledge-qemuarm/firmware.uefi.uboot.bin|"`
             export CERTS_URL=`echo ${SYSTEM_URL} | sed -e "s|ledge-qemuarm.*|ledge-qemuarm/ledge-kernel-uefi-certs.ext4.img|"`
      elif  [ "${MACHINE}" = "ledge-multi-armv8" ]; then
             export FIRMWARE_URL=`echo ${SYSTEM_URL} | sed -e "s|ledge-qemuarm64.*|ledge-qemuarm64/firmware.uefi.uboot.bin|"`
             export CERTS_URL=`echo ${SYSTEM_URL} | sed -e "s|ledge-qemuarm64.*|ledge-qemuarm64/ledge-kernel-uefi-certs.ext4.img|"`
      fi
}

DTYPES="${DEVICE_TYPE}"

for DEVICE_TYPE in ${DTYPES}; do
      export DEVICE_TYPE
      if [ -z "${DEBIAN}" ]; then
         oe_urls
      fi

      python configs/openembedded-lkft/submit_for_testing.py \
         --device-type ${DEVICE_TYPE} \
         --build-number ${BUILD_NUMBER} \
         --lava-server ${LAVA_SERVER} \
         --qa-server ${QA_SERVER} \
         --qa-server-team ${QA_SERVER_TEAM} \
         --qa-server-project ${QA_SERVER_PROJECT} \
         --git-commit ${MANIFEST_COMMIT} \
         --template-path configs/rpb-openembedded/lava-job-definitions \
         --template-names template-boot.yaml
done
