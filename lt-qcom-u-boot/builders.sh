#!/bin/bash

set -ex

export PATH=${tcbindir}:$PATH

CONFIG=""
case "${MACHINE}" in
	dragonboard-410c)
	CONFIG=dragonboard410c_defconfig
	;;
	*)
	echo "Machine "${MACHINE}" not supported."
	exit 1
 	;;
esac

make distclean
make $CONFIG
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)

gzip -k u-boot.bin
touch fake_rd.img
skales-mkbootimg --kernel=u-boot.bin.gz --output=u-boot.img --dt=u-boot.dtb \
  --pagesize 2048 --base 0x80000000 --ramdisk=fake_rd.img --cmdline=""

mkdir -p out/

cp u-boot.bin.gz out/
cp u-boot.dtb out/
cp u-boot.img out/
