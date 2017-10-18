#!/bin/bash

# Prepare files to publish
mkdir -p ${WORKSPACE}/out-publish
cp -a \
  ${HOME}/optee_repo/gen_rootfs/filesystem.cpio.gz \
  ${HOME}/optee_repo/linux/arch/arm/boot/zImage \
  ${HOME}/optee_repo/out/bios-qemu/bios.bin \
  ${HOME}/optee_repo/qemu/arm-softmmu/qemu-system-arm \
  ${HOME}/optee_repo/qemu/pc-bios/efi-virtio.rom \
  ${WORKSPACE}/out/arm/core/tee-header_v2.bin \
  ${WORKSPACE}/out/arm/core/tee-pageable_v2.bin \
  ${WORKSPACE}/out/arm/core/tee-pager_v2.bin \
  ${WORKSPACE}/out-publish/

mv ${WORKSPACE}/out-publish/filesystem.cpio.gz \
  ${WORKSPACE}/out-publish/rootfs.cpio.gz

strip ${WORKSPACE}/out-publish/qemu-system-arm

# FIXME: tee-pageable_v2.bin file size is 0
# It triggers an error 501 on LLP
rm -f  ${WORKSPACE}/out-publish/tee-pageable_v2.bin

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  ${WORKSPACE}/out-publish ${PUB_DEST}
