#!/bin/sh

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
# Used by DB410C's template:
export RESIZE_ROOTFS=${RESIZE_ROOTFS:-}

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

if [ -z "${DEVICE_TYPE}" ]; then
    if [ "${MACHINE}" = "ledge-multi-armv7" ]; then
        #DEVICE_TYPE="qemuarmuefi stm32mp157c-dk2 x15-bl_uefi"
        DEVICE_TYPE="qemuarmuefi qemuarm_atf_fip"
    elif [ "${MACHINE}" = "ledge-multi-armv8" ]; then
        DEVICE_TYPE="qemuarm64uefi  synquacer qemuarm64_atf_fip"
    fi
fi

DTYPES="${DEVICE_TYPE}"

for DEVICE_TYPE in ${DTYPES}; do
      export DEVICE_TYPE
      if [ "${MACHINE}" = "ledge-multi-armv7" ]; then
         if [ "${DEVICE_TYPE}" = "x15-bl_uefi"; then
             export SYSTEM_URL=`echo ${SYSTEM_URL} | sed  "s/ledge-qemuarm/ledge-ti-am572x/"`
         fi
             export FIRMWARE_URL=`echo ${SYSTEM_URL} | sed -e "s|ledge-qemuarm.*|ledge-qemuarm/firmware.bin|"`
             export CERTS_URL=`echo ${SYSTEM_URL} | sed -e "s|ledge-qemuarm.*|ledge-qemuarm/ledge-kernel-uefi-certs.ext4.img|"`
      elif  [ "${MACHINE}" = "ledge-multi-armv8" ]; then
             export FIRMWARE_URL=`echo ${SYSTEM_URL} | sed -e "s|ledge-qemuarm64.*|ledge-qemuarm64/firmware.bin|"`
             export CERTS_URL=`echo ${SYSTEM_URL} | sed -e "s|ledge-qemuarm64.*|ledge-qemuarm64/ledge-kernel-uefi-certs.ext4.img|"`
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
