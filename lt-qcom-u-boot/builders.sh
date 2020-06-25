#!/bin/bash

set -ex

export PATH=${tcbindir}:$PATH
UBOOT_DIR="${WORKSPACE}/uboot"
OUT_DIR="out"

CONFIG=""
case "${MACHINE}" in
	dragonboard-410c)
	CONFIG="dragonboard410c_defconfig"
	;;
	*)
	echo "Machine "${MACHINE}" not supported."
	exit 1
 	;;
esac

make -C ${UBOOT_DIR} distclean
make -j$(nproc) \
     -C ${UBOOT_DIR} \
     ARCH=arm \
     CROSS_COMPILE=aarch64-linux-gnu- \
     ${CONFIG}
make -j$(nproc) \
     -C ${UBOOT_DIR} \
     ARCH=arm \
     CROSS_COMPILE=aarch64-linux-gnu-

gzip -k u-boot.bin
touch fake_rd.img
skales-mkbootimg --kernel=u-boot.bin.gz --output=u-boot.img --dt=u-boot.dtb \
  --pagesize 2048 --base 0x80000000 --ramdisk=fake_rd.img --cmdline=""

mkdir -p ${OUT_DIR}
cp u-boot.bin.gz ${OUT_DIR}
cp u-boot.dtb ${OUT_DIR}
cp u-boot.img ${OUT_DIR}
