#!/bin/bash

set -ex

git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9
export PATH=${PATH}:${PWD}/aarch64-linux-android-4.9/bin/

make ARCH=arm64 hikey_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- -j$(nproc) -s Image-dtb

wget -q https://android-git.linaro.org/platform/system/core.git/plain/mkbootimg/mkbootimg -O mkbootimg
wget -q ${REFERENCE_BUILD_URL}/ramdisk.img -O ramdisk.img

mkdir -p out
python mkbootimg \
  --kernel ${PWD}/arch/arm64/boot/Image-dtb \
  --cmdline console="ttyFIQ0 androidboot.console=ttyFIQ0 androidboot.hardware=hikey firmware_class.path=/system/etc/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug" \
  --os_version O \
  --os_patch_level 2016-11-05 \
  --ramdisk ramdisk.img \
  --output out/boot.img
xz out/boot.img
