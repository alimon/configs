#!/bin/bash


if [ ! -d "${WORKSPACE}" ]; then
    set -x
    WORKSPACE=$(pwd)
else
    set -ex
fi
if [ -z "${ARCH}" ]; then
    export ARCH=arm64
fi

mkdir -p out
(cd linux/INSTALL_MOD_PATH && find . | cpio -R 0:0 -ov -H newc | gzip > ${WORKSPACE}/out/kernel-modules.cpio.gz)
(cd linux/INSTALL_MOD_PATH && tar cJvf ${WORKSPACE}/out/kernel-modules.tar.xz .)
cp linux/.config ${WORKSPACE}/out/kernel.config
cp linux/{System.map,vmlinux} ${WORKSPACE}/out/
cp linux/arch/$ARCH/boot/Image* ${WORKSPACE}/out/
(mkdir -p out/dtbs && cd linux/arch/$ARCH/boot/dts && cp -a --parents $(find . -name *.dtb) ${WORKSPACE}/out/dtbs)

BRANCH_NAME_URL=$(echo ${KERNEL_BRANCH} | sed -e 's/[^A-Za-z0-9._-]/_/g')
echo "PUB_DEST=member-builds/qcomlt/kernel/${BRANCH_NAME_URL}/${BUILD_NUMBER}" > pub_dest_parameters
