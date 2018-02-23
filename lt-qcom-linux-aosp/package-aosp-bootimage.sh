#!/bin/bash -xe

cat ${WORKSPACE}/linux/arch/${ARCH}/boot/Image.gz ${WORKSPACE}/linux/arch/${ARCH}/boot/dts/qcom/apq8016-sbc.dtb > Image.gz-dtb
wget -q https://android-git.linaro.org/platform/system/core.git/plain/mkbootimg/mkbootimg -O mkbootimg
wget -q ${REFERENCE_BUILD_URL}/ramdisk.img -O ramdisk.img
python mkbootimg --kernel Image.gz-dtb --ramdisk ramdisk.img --output boot-db410c.img --pagesize 2048 --base 0x80000000 --cmdline 'androidboot.selinux=permissive firmware_class.path=/system/vendor/firmware/'
