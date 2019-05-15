#!/bin/bash

set -ex

virtualenv --python=$(which python2) .venv
source .venv/bin/activate
pip install Jinja2 requests urllib3 ruamel.yaml

export BUILD_NUMBER=530
export OS_FLAVOUR=buster
export VENDOR=linaro
export PLATFORM_NAME=dragonboard-410c
export QA_SERVER="http://localhost:8000"
export QA_REPORTS_TOKEN="secret"
export LAVA_SERVER=https://validation.linaro.org/RPC2/
export PMWG_LAVA_SERVER=https://pmwg.validation.linaro.org/RPC2/
export ARTIFACTORIAL_TOKEN="nosecret"
export DRY_RUN="--dry-run "

export DEVICE_TYPE=dragonboard-410c
export PUBLISH_SERVER=https://snapshots.linaro.org/
export PUB_DEST=96boards/dragonboard410c/${VENDOR}/debian/${BUILD_NUMBER}
bash submit_for_testing.sh

# cleanup virtualenv
deactivate
rm -rf .venv
