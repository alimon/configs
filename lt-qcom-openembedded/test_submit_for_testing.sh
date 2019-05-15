#!/bin/bash

set -ex

virtualenv --python=$(which python2) .venv
source .venv/bin/activate
pip install Jinja2 requests urllib3 ruamel.yaml

export BUILD_NUMBER=125
export DISTRO=rpb
export MANIFEST_BRANCH=thud
export QA_SERVER="http://localhost:8000"
export QA_REPORTS_TOKEN="secret"
export LAVA_SERVER=https://validation.linaro.org/RPC2/
export DRY_RUN="--dry-run "

export MACHINE=dragonboard-410c
export BOOT_URL=https://snapshots.linaro.org/96boards/dragonboard410c/linaro/openembedded/thud/125/rpb/boot--4.14-r0-dragonboard-410c-20190409213001-125.img
export ROOTFS_SPARSE_BUILD_URL=https://snapshots.linaro.org/96boards/dragonboard410c/linaro/openembedded/thud/125/rpb/rpb-console-image-test-dragonboard-410c-20190409213001-125.rootfs.img.gz
bash submit_for_testing.sh

# cleanup virtualenv
deactivate
rm -rf .venv
