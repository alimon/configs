#!/bin/bash

cd ${WORKSPACE}/armnn-snapshot && rm -rf SHA256SUMS.txt && sha256sum > SHA256SUMS.txt

test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py

time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  ${WORKSPACE}/armnn-snapshot ${PUB_DEST}
