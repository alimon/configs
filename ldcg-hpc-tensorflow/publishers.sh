#!/bin/bash

set -ex

dnf install -y python3-requests

# Publish wheel files
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python3 ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  ${WORKSPACE}/out \
  hpc/python/tensorflow/${BUILD_NUMBER}

set +x

echo "Python wheels: https://snapshots.linaro.org/hpc/python/tensorflow/${BUILD_NUMBER}/"
