#!/bin/bash

set -ex

if [ `echo $JOB_NAME | cut -d'/' -f1` == 'ldcg-python-tensorflow-nightly' ]; then
  OUTPUT_PATH="ldcg/python/tensorflow-nightly/$(date -u +%Y%m%d)-${BUILD_NUMBER}/"
else
  OUTPUT_PATH="ldcg/python/tensorflow/${BUILD_NUMBER}/"
fi

if [ -e /etc/centos-release ]; then
   sudo dnf install -y python3-requests wget
   # NOTE(hrw): just in case as we had urllib3 issue with six
   sudo dnf reinstall -y python3-six python3-urllib3
fi

# Publish wheel files
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python3 ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  /home/buildslave/wheels \
  $OUTPUT_PATH || true

set +x

echo "Python wheels: https://snapshots.linaro.org/$OUTPUT_PATH"
