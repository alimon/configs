#!/bin/bash

COPY_FROM=/home/buildslave/wheels/
PUBLISH_TO=ldcg/python-cache/

set -ex

if [ -e /etc/debian_version ]; then
  BUILD_NUMBER="${BUILD_NUMBER}-debian"
else
   sudo dnf install -y python3-requests wget
fi

ls -alR $COPY_FROM

# Publish wheel files
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python3 ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --no-build-info \
  $COPY_FROM \
  $PUBLISH_TO

set +x

echo "Python wheels: https://snapshots.linaro.org/${PUBLISH_TO}"
