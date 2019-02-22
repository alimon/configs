#!/bin/bash

set -ex

# Create MD5SUMS file
(cd out && md5sum $(find . -type f) > MD5SUMS.txt)

wget -q ${BUILD_URL}consoleText -O out/build-log-$(echo ${JOB_NAME}|sed -e 's/[^A-Za-z0-9._-]/_/g')-${BUILD_NUMBER}.txt

# Publish to snapshots
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
     --server ${PUBLISH_SERVER} \
     --link-latest \
     out ${PUB_DEST}
