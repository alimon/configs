#!/bin/bash

set -ex

if [ -e /etc/debian_version ]; then
    BUILD_NUMBER="${BUILD_NUMBER}-debian"
else
    BUILD_NUMBER="${BUILD_NUMBER}-centos"
    sudo dnf install -y python3-requests wget
fi

ls -alR /home/buildslave/wheels

# Publish wheel files
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python3 ${HOME}/bin/linaro-cp.py \
    --server ${PUBLISH_SERVER} \
    --link-latest \
    /home/buildslave/wheels \
    ldcg/python/pytorch/${BUILD_NUMBER}

set +x

echo "Python wheels: https://snapshots.linaro.org/ldcg/python/pytorch/${BUILD_NUMBER}/"
