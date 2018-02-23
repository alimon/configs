#!/bin/bash
# Install ruamel.yaml
pip install --user --force-reinstall ruamel.yaml
pip install --user --force-reinstall Jinja2

# export VTS_URL=https://builds.96boards.org/${PUB_DEST}
# export CTS_URL=https://builds.96boards.org/${PUB_DEST}
export DEVICE_TYPE=db410c-android
export LAVA_SERVER=https://validation.linaro.org/RPC2/
export DOWNLOAD_URL=https://snapshots.linaro.org/96boards/dragonboard410c/linaro/aosp/kernel/${BUILD_NUMBER}
export REFERENCE_BUILD_URL=${REFERENCE_BUILD_URL}
export KERNEL_COMMIT=${KERNEL_VERSION}
export KERNEL_BRANCH=${KERNEL_BRANCH}
export KERNEL_REPO=${KERNEL_REPO_URL}
export ANDROID_VERSION=aosp-master
# export VTS_VERSION=$(echo $VTS_URL | awk -F"/" '{print$(NF-1)}')
# export CTS_VERSION=$(echo $CTS_URL | awk -F"/" '{print$(NF-1)}')
export QA_BUILD_VERSION=${BUILD_NUMBER}

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git

python configs/openembedded-lkft/submit_for_testing.py \
    --device-type ${DEVICE_TYPE} \
    --build-number ${BUILD_NUMBER} \
    --lava-server ${LAVA_SERVER} \
    --qa-server ${QA_SERVER} \
    --qa-server-team qcomlt \
    --qa-server-project ${QA_SERVER_PROJECT} \
    --git-commit ${QA_BUILD_VERSION} \
    --template-path configs/lt-qcom-linux-aosp/lava-job-definitions/dragonboard410c \
    --template-names template-boot.yaml \
    --quiet
