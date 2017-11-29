#!/bin/bash

set -ex

# copy files which can be published, if needed
mkdir out
cp vmlinux arch/${ARCH}/boot/Image.gz out
cp .config out/kernel.config
cp arch/${ARCH}/configs/defconfig out
for f in ${KERNEL_DTBS}; do
    cp arch/${ARCH}/boot/dts/$f out;
done

# Create MD5SUMS file
(cd out && md5sum * > MD5SUMS.txt)

wget -q ${BUILD_URL}consoleText -O out/build-log-${JOB_NAME}-${BUILD_NUMBER}.txt

# Publish to snapshots
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
     --server ${PUBLISH_SERVER} \
     --link-latest \
     out ${PUB_DEST}
