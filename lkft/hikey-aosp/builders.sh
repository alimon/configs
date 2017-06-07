#!/bin/bash

set -x

git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9
export PATH=${PATH}:${PWD}/aarch64-linux-android-4.9/bin/

make ARCH=arm64 hikey_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- -j$(nproc) Image-dtb

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

wget -q ${REFERENCE_BUILD_URL}/build_config.json -O out/build_config.json
remote=$(git remote -v | grep push | cut -d" " -f1 | cut -f2)
commit=$(git log | grep commit | cut -d" " -f2)
sed -i "s|\"kernel_repo\" : \"|\"kernel_repo\" : \"$remote|g" out/build_config.json
sed -i "s|\"kernel_commit_id\" : \"|\"kernel_commit_id\" : \"$commit|g" out/build_config.json
sed -i "s|\"kernel_branch\" : \"|\"kernel_branch\" : \"$KERNEL_BRANCH|g" out/build_config.json
