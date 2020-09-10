#!/bin/bash

set -ex

sudo dnf install -y python3-requests

ls -alR /var/tmp/workspace/out

# Publish wheel files
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python3 ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  /var/tmp/workspace/out \
  hpc/python/pytorch/${BUILD_NUMBER}

set +x

echo "Python wheels: https://snapshots.linaro.org/hpc/python/pytorch/${BUILD_NUMBER}/"
