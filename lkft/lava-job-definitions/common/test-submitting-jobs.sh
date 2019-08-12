#!/bin/bash

F_ABS_PATH=$(readlink -e $0)
DIR_PARENT=$(dirname ${F_ABS_PATH})

export BUILD_NUMBER=70
export JOB_NAME=lkft-x15-android-9.0-4.19
export BUILD_URL=https://ci.linaro.org/job/lkft-x15-android-9.0-4.19/70/
export SRCREV_kernel=d7c49b80d185fe33efaa2ab51b86150ac10bd66a
export KERNEL_DESCRIBE=ti2019.03-rc1-android-57-gd7c49b80d185
export AP_SSID=ap_ssid #needed for test hikey
export AP_KEY=ap_key # needed for test hikey

export ENV_DRY_RUN=true
export ARTIFACTORIAL_TOKEN=xxxx
export ANDROID_BUILD_CONFIG="lkft-x15-android-9.0-4.19 lkft-x15-android-9.0-4.19-auto"

virtualenv .venv
source .venv/bin/activate
pip install Jinja2 requests urllib3 ruamel.yaml

${DIR_PARENT}/submit_for_testing-v2.sh
