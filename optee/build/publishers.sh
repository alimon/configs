#!/bin/bash

# Prepare files to publish
mkdir -p ${WORKSPACE}/out-publish
cp -a \
  ${WORKSPACE}/${repo_proj}/arm-trusted-firmware/build/juno/release/bl1.bin \
  ${WORKSPACE}/${repo_proj}/arm-trusted-firmware/build/juno/release/fip.bin \
  ${WORKSPACE}/${repo_proj}/gen_rootfs/ramdisk.img \
  ${WORKSPACE}/${repo_proj}/linux/arch/arm64/boot/Image \
  ${WORKSPACE}/${repo_proj}/linux/arch/arm64/boot/dts/arm/juno*.dtb \
  ${WORKSPACE}/${repo_proj}/vexpress-firmware/SOFTWARE/bl0.bin \
  ${WORKSPACE}/out-publish/

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  ${WORKSPACE}/out-publish ${PUB_DEST}
