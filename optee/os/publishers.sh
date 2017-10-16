#!/bin/bash

# Prepare files to publish
mkdir -p ${WORKSPACE}/out-publish
cp -a \
  ${HOME}/optee_repo/out/bios-qemu/bios.bin \
  ${HOME}/optee_repo/qemu/arm-softmmu/qemu-system-arm \
  ${WORKSPACE}/out-publish/

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  ${WORKSPACE}/out-publish components/optee/os/${BUILD_NUMBER}
