#!/bin/bash

set -ex

ls -alR ${WORKSPACE}/logs

if [ -e ${WORKSPACE}/logs/sbsa-acs-level3.log ]; then
  # ldcg-sbsa-acs job
  PUBLISH_PATH=ldcg/sbsa-acs
else
  # ldcg-sbsa-firmware job
  PUBLISH_PATH=ldcg/sbsa-enterprise-acs
fi

# Publish log files
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python3 ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  ${WORKSPACE}/logs \
  ${PUBLISH_PATH}/${BUILD_NUMBER}

set +x

echo "SBSA ACS logs: https://snapshots.linaro.org/${PUBLISH_PATH}/${BUILD_NUMBER}/"
