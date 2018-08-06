#!/bin/bash

echo "TBD what we are going to publish"
exit 0

# Prepare files to publish
mkdir -p ${WORKSPACE}/out-publish
cp -a <files> ${WORKSPACE}/out-publish/

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  ${WORKSPACE}/out-publish ${PUB_DEST}
