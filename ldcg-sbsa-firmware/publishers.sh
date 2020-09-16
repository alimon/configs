#!/bin/bash

set -ex

ls -alR /var/tmp/workspace/logs

PUBLISH_PATH=ldcg/sbsa-acs

# Publish log files
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python3 ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  /var/tmp/workspace/out \
  ${PUBLISH_PATH}/${BUILD_NUMBER}

set +x

echo "SBSA ACS logs: https://snapshots.linaro.org/${PUBLISH_PATH}/${BUILD_NUMBER}/"
