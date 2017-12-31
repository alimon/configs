#!/bin/bash

set -x

PUBLISH_SCRIPT=${PUBLISH_SCRIPT:-https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py}

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q ${PUBLISH_SCRIPT} -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  ${DEPLOY_DIR_IMAGE}/ ${PUB_DEST}
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --make-link \
  $(dirname ${PUB_DEST})
