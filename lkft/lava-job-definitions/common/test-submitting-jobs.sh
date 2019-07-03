#!/bin/bash

F_ABS_PATH=$(readlink -e $0)
DIR_PARENT=$(dirname ${F_ABS_PATH})

export ANDROID_BUILD_CONFIG=lkft-hikey960-android-9.0-4.19
export BUILD_NUMBER=23
export JOB_NAME=lkft-hikey960-android-9.0-4.19
export BUILD_URL=https://ci.linaro.org/job/lkft-hikey-android-9.0-4.19/23/
export SRCREV_kernel=fe2d6361587b6feda2f21bf9c98d2d6a913c237c
export KERNEL_DESCRIBE=v4.19.56-568-gfe2d6361587b
export AP_SSID=ap_ssid #needed for test hikey
export AP_KEY=ap_key # needed for test hikey

export ENV_DRY_RUN=true
export ARTIFACTORIAL_TOKEN=xxxx
export ANDROID_BUILD_CONFIG="lkft-hikey960-android-9.0-4.19 lkft-hikey-android-9.0-4.19"

virtualenv .venv
source .venv/bin/activate
pip install Jinja2 requests urllib3 ruamel.yaml

${DIR_PARENT}/submit_for_testing-v2.sh
