#!/bin/bash

cat > ${WORKSPACE}/BUILD-INFO.txt << EOF
Format-Version: 0.5

Files-Pattern: *
License-Type: protected
Auth-Groups: playready-confidential-access
EOF

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --build-info ${WORKSPACE}/BUILD-INFO.txt \
  ${DEPLOY_DIR_IMAGE}/ ${PUB_DEST}
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --make-link \
  $(dirname ${PUB_DEST})
