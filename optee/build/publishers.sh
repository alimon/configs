#!/bin/bash

# Prepare files to publish
mkdir -p ${WORKSPACE}/out-publish
cp -a \
  ${WORKSPACE}/${repo_proj}/arm-trusted-firmware/build/juno/release/bl1.bin \
  ${WORKSPACE}/${repo_proj}/arm-trusted-firmware/build/juno/release/fip.bin \
  ${WORKSPACE}/${repo_proj}/gen_rootfs/ramdisk.img \
  ${WORKSPACE}/${repo_proj}/linux/arch/arm64/boot/Image \
  ${WORKSPACE}/${repo_proj}/linux/arch/arm64/boot/dts/arm/juno*.dtb \
  ${WORKSPACE}/out-publish/

# Create new recovery image
wget -q http://releases.linaro.org/members/arm/platforms/17.04/juno-latest-oe-uboot.zip -O juno-latest-oe-uboot.zip
unzip -d juno-oe-uboot juno-latest-oe-uboot.zip

for file in bl1.bin fip.bin ramdisk.img Image juno.dtb juno-r1.dtb juno-r2.dtb; do
  cp -a ${WORKSPACE}/out-publish/${file} ${WORKSPACE}/juno-oe-uboot/SOFTWARE/${file}
done

# Note: uncomment and adjust adresses to give more space for a larger kernel or ramdisk
#sed -i -e 's/^NOR4ADDRESS:.*/NOR4ADDRESS: 0x02200000          ;Image Flash Address/g' \
#  ${WORKSPACE}/juno-oe-uboot/SITE1/*/images.txt
cat ${WORKSPACE}/juno-oe-uboot/SITE1/*/images.txt

cd ${WORKSPACE}/juno-oe-uboot/
zip -r ${WORKSPACE}/out-publish/juno-oe-uboot.zip .

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  ${WORKSPACE}/out-publish ${PUB_DEST}
