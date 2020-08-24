#!/bin/bash

if [ -f ${WORKSPACE}/BUILD-INFO.txt ];then
    BUILD_INFO="--build-info ${WORKSPACE}/BUILD-INFO.txt"
else
    BUILD_INFO=""
fi

if [ -z "${DEPLOY_DIR_IMAGE}" ] || [ -z "${PUB_DEST}" ] || [ -z "${PUBLISH_SERVER}" ]
then
    echo "== missing publishing variables =="
    echo "DEPLOY_DIR_IMAGE = ${DEPLOY_DIR_IMAGE}"
    echo "PUB_DEST         = ${PUB_DEST}"
    echo "PUBLISH_SERVER   = ${PUBLISH_SERVER}"
    exit 1
fi

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python3 ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  ${BUILD_INFO} \
  ${DEPLOY_DIR_IMAGE}/ ${PUB_DEST}
time python3 ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --make-link \
  $(dirname ${PUB_DEST})
