#!/bin/bash

set -ex

export PATH=${tcbindir}:$PATH
UBOOT_DIR="${WORKSPACE}/uboot"
OUT_DIR="out"

CONFIG=""
case "${MACHINE}" in
	dragonboard410c)
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
     CROSS_COMPILE=aarch64-none-linux-gnu- \
     ${CONFIG}
make -j$(nproc) \
     -C ${UBOOT_DIR} \
     ARCH=arm \
     CROSS_COMPILE=aarch64-none-linux-gnu-

mkdir -p ${OUT_DIR}

cat > out/HEADER.textile << EOF

h4. QCOM Landing Team - $BUILD_DISPLAY_NAME

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Uboot Repository: "$UBOOT_REPO_URL":$UBOOT_REPO_URL
* Uboot Branch: $UBOOT_BRANCH
* Uboot Revision: $GIT_COMMIT
EOF

git_short_rev="$(echo $GIT_COMMIT | cut -c1-8)"

gzip -k uboot/u-boot.bin
touch fake_rd.img
skales-mkbootimg --kernel=uboot/u-boot.bin.gz --output=out/u-boot-$BUILD_NUMBER-$git_short_rev.img --dt=uboot/u-boot.dtb \
  --pagesize 2048 --base 0x80000000 --ramdisk=fake_rd.img --cmdline=""
cp uboot/u-boot.bin.gz ${OUT_DIR}/u-boot-$BUILD_NUMBER-$git_short_rev.bin.gz
cp uboot/u-boot.dtb ${OUT_DIR}/u-boot-$BUILD_NUMBER-$git_short_rev.dtb
