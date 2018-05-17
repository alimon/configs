#!/bin/bash

set -ex

# Publish logs
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  ${WORKSPACE}/kolla/logs/debian-source reference-platform/enterprise/components/openstack/kolla-logs/${BUILD_NUMBER}

set +x

echo "Images: https://hub.docker.com/u/linaro/"
echo "Logs:   https://snapshots.linaro.org/reference-platform/enterprise/components/openstack/kolla-logs/${BUILD_NUMBER}/"
