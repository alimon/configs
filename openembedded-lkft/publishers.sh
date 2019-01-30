#!/bin/bash

set -ex


# Generate checksums for use in LAVA jobs
( cd ${DEPLOY_DIR_IMAGE} && rm -f SHA256SUMS.txt && find -maxdepth 1 -type f -exec sha256sum {} + > SHA256SUMS.txt )

test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py

# Publish
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  ${DEPLOY_DIR_IMAGE}/ ${PUB_DEST}
