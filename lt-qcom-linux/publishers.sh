#!/bin/bash

set -ex

# make sure there are no left over files
rm -rf out/
# copy files which can be published, if needed
mkdir out
cp ${WORKSPACE}/linux/vmlinux ${WORKSPACE}/linux/arch/${ARCH}/boot/Image.gz out
cp ${WORKSPACE}/linux/.config out/kernel.config
cp ${WORKSPACE}/linux/arch/${ARCH}/configs/defconfig out
for f in ${KERNEL_DTBS}; do
    cp ${WORKSPACE}/linux/arch/${ARCH}/boot/dts/$f out;
done

if [ -e ${WORKSPACE}/boot-db410c.img ]; then
    cp ${WORKSPACE}/boot-db410c.img out
fi

# Create MD5SUMS file
(cd out && md5sum * > MD5SUMS.txt)

wget -q ${BUILD_URL}consoleText -O out/build-log-$(echo ${JOB_NAME}|sed -e 's/[^A-Za-z0-9._-]/_/g')-${BUILD_NUMBER}.txt

# Publish to snapshots
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
     --server ${PUBLISH_SERVER} \
     --link-latest \
     out ${PUB_DEST}
