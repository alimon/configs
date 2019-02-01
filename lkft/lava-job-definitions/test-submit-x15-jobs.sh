#!/bin/bash -ex

parent_dir=$(cd $(dirname $0); pwd)


export PUB_DEST=96boards/hikey/linaro/aosp-master/1107
export VTS_URL=http://snapshots.linaro.org/96boards/hikey/linaro/aosp-master/1107
export CTS_URL=http://snapshots.linaro.org/96boards/hikey/linaro/aosp-master/1107
export DOWNLOAD_URL=http://snapshots.linaro.org/96boards/hikey/linaro/aosp-master/1107
export REFERENCE_BUILD_URL=http://snapshots.linaro.org/96boards/hikey/linaro/aosp-master/1107
export KERNEL_COMMIT=1107
export ANDROID_VERSION=aosp-master-2019-02-01
export VTS_VERSION=aosp-master
export CTS_VERSION=aosp-master
export QA_BUILD_VERSION=1107

export DEVICE_TYPE=x15
export TOOLCHAIN=gcc-linaro-7.2.1-2017.11-x86_64_arm-eabi
export KERNEL_REPO=omap
export KERNEL_DESCRIBE=787751264d17
export SRCREV_kernel=787751264d17
export KERNEL_BRANCH=android-beagle-x15-4.14-787751264d17
export LAVA_SERVER=https://lkft.validation.linaro.org/RPC2/

export BUILD_NUMBER=1107
export JOB_NAME=96boards-hikey-aosp-master
export BUILD_URL=https://ci.linaro.org/job/96boards-hikey-aosp-master/1107/
export ARTIFACTORIAL_TOKEN=ARTIFACTORIAL_TOKEN
export AP_KEY=AP_KEY
export AP_SSID=AP_SSID

export BOOTARGS='androidboot.serialno=${serial#} console=ttyS2,115200 androidboot.console=ttyS2 androidboot.hardware=am57xevmboard'


python ${parent_dir}/../..//openembedded-lkft/submit_for_testing.py \
    --device-type x15 \
    --build-number 1107 \
    --lava-server https://lkft.validation.linaro.org/RPC2/ \
    --qa-server https://qa-reports.linaro.org \
    --qa-server-team android-lkft \
    --env-suffix _4.14 \
    --qa-server-project aosp-master-tracking \
    --git-commit 1107 \
    --testplan-path lkft/lava-job-definitions/x15 \
    --test-plan template-boot.yaml \
                template-vts-kernel-syscalls.yaml \
                template-cts-displaytestcases.yaml \
                template-vts-kselftest.yaml \
                template-cts.yaml \
                template-vts-kernel-ltp.yaml \
    --dry-run \
    --quiet

exit $?
