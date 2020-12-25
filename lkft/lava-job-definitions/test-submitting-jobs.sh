#!/bin/bash

F_ABS_PATH=$(readlink -e $0)
DIR_PARENT=$(dirname ${F_ABS_PATH})

export LKFT_WORK_DIR=$(pwd)

export BUILD_NUMBER=2442
export JOB_NAME=lkft-generic-build
export BUILD_URL=https://ci.linaro.org/job/${JOB_NAME}/${BUILD_NUMBER}
export SRCREV_kernel=4a559bce32b9ad5d5ec264d4a517f4bf34d87b32
export KERNEL_DESCRIBE=5.10.0-4a559bce32b9
export AP_SSID=ap_ssid #needed for test hikey
export AP_KEY=ap_key # needed for test hikey

export ENV_DRY_RUN=true
export ARTIFACTORIAL_TOKEN=xxxx
export ANDROID_BUILD_CONFIG="lkft-hikey960-aosp-master-mainline-gki"

for f in ${ANDROID_BUILD_CONFIG}; do
    mkdir -p out/${f}
    rm -f out/${f}/misc_info.txt
    cat >> out/${f}/misc_info.txt <<__EOF__
VENDOR_KERNEL_CLANG_VER=clang-r399163b
KERNEL_BRANCH=android-mainline
KERNEL_REPO=https://android.googlesource.com/kernel/common
VENDOR_KERNEL_MAKEVERSION=5.10.0
VENDOR_KERNEL_COMMIT=4162f006bd11db3af3a16c1048e204d0e55e593a
GKI_KERNEL_MAKEVERSION=5.10.0
GKI_KERNEL_COMMIT=4162f006bd11db3af3a16c1048e204d0e55e593a
__EOF__

done

virtualenv .venv
source .venv/bin/activate
pip install Jinja2 requests urllib3 ruamel.yaml

${DIR_PARENT}/submit_for_testing-v2.sh
