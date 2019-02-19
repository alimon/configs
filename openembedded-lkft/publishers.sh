#!/bin/bash

set -ex


# Generate checksums for use in LAVA jobs
( cd ${DEPLOY_DIR_IMAGE} && rm -f SHA256SUMS.txt && find -maxdepth 1 -type f -exec sha256sum {} + > SHA256SUMS.txt )

test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py

# LLP
if [ -n "${LLP_GROUP}" ]; then
  cat > "${WORKSPACE}/BUILD-INFO.txt" << EOF
Format-Version: 0.5

Files-Pattern: *
License-Type: protected
Auth-Groups: ${LLP_GROUP}
EOF
fi

# Publish
if [ -e "${WORKSPACE}/BUILD-INFO.txt" ]; then
  time python ${HOME}/bin/linaro-cp.py \
    --server ${PUBLISH_SERVER} \
    --build-info ${WORKSPACE}/BUILD-INFO.txt \
    --link-latest \
    ${DEPLOY_DIR_IMAGE}/ ${PUB_DEST}
else
  time python ${HOME}/bin/linaro-cp.py \
    --server ${PUBLISH_SERVER} \
    --link-latest \
    ${DEPLOY_DIR_IMAGE}/ ${PUB_DEST}
fi
