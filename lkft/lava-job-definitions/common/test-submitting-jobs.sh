#!/bin/bash

F_ABS_PATH=$(readlink -e $0)
DIR_PARENT=$(dirname ${F_ABS_PATH})

export ANDROID_BUILD_CONFIG=lkft-am65x-android-9.0-4.19
export BUILD_NUMBER=9
export JOB_NAME=lkft-am65x-android-9.0-4.19
export BUILD_URL=https://ci.linaro.org/job/lkft-am65x-android-9.0-4.19/9/
export SRCREV_kernel=03c2fa3c798ae43152f085ff87125fcc928fe007
export KERNEL_DESCRIBE=v4.19.41-2172-g03c2fa3c798a
export AP_SSID=ap_ssid #needed for test hikey
export AP_KEY=ap_key # needed for test hikey

export ENV_DRY_RUN=true
export ARTIFACTORIAL_TOKEN=xxxx
export ANDROID_BUILD_CONFIG="lkft-hikey-android-9.0-4.19-premerge lkft-am65x-android-9.0-4.19-premerge lkft-x15-android-9.0-4.19-premerge"

virtualenv .venv
source .venv/bin/activate
pip install Jinja2 requests urllib3 ruamel.yaml

${DIR_PARENT}/submit_for_testing-v2.sh
