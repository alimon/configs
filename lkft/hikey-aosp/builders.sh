#!/bin/bash

git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9
export PATH=${PATH}:${PWD}/aarch64-linux-android-4.9/bin/

make ARCH=arm64 hikey_defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- Image-dtb

wget -q https://android-git.linaro.org/platform/system/core.git/plain/mkbootimg/mkbootimg -O mkbootimg
wget -q ${REFERENCE_AOSP_BUILD}/ramdisk.img -O ramdisk.img
python mkbootimg \
  --kernel ${PWD}/arch/arm64/boot/Image-dtb \
  --cmdline console="ttyFIQ0 androidboot.console=ttyFIQ0 androidboot.hardware=hikey firmware_class.path=/system/etc/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug" \
  --os_version O \
  --os_patch_level 2016-11-05 \
  --ramdisk ramdisk.img \
  --output boot.img

mkdir -p out && mv boot.img out/

wget -q https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/hikey/build-info/aosp-master-template.txt -O out/BUILD-INFO.txt

# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
PUB_DEST=snapshots/lkft/${JOB_NAME}/${BUILD_NUMBER}
PUB_SRC=${PWD}/out/
EOF
