#!/bin/bash

set -ex

git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9
export PATH=${PATH}:${PWD}/aarch64-linux-android-4.9/bin/

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="python-pip openssl libssl-dev"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

make ARCH=arm64 ${DEFCONFIG}
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- -j$(nproc) -s Image-dtb

wget -q https://android-git.linaro.org/platform/system/core.git/plain/mkbootimg/mkbootimg -O mkbootimg
wget -q ${REFERENCE_BUILD_URL}/ramdisk.img -O ramdisk.img

mkdir -p out
case "${DEFCONFIG}" in
  hikey_defconfig)
    python mkbootimg \
      --kernel ${PWD}/arch/arm64/boot/Image-dtb \
      --cmdline "console=ttyFIQ0 androidboot.console=ttyFIQ0 androidboot.hardware=hikey firmware_class.path=/system/etc/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug" \
      --os_version O \
      --os_patch_level 2016-11-05 \
      --ramdisk ramdisk.img \
      --output out/boot.img
    ;;
  hikey960_defconfig)
    python mkbootimg \
      --kernel ${PWD}/arch/arm64/boot/Image-dtb \
      --cmdline "androidboot.hardware=hikey960 console=ttyFIQ0 androidboot.console=ttyFIQ0 firmware_class.path=/vendor/firmware loglevel=15 buildvariant=userdebug" \
      --base 0x0 --tags_offset 0x07a00000 --kernel_offset 0x00080000 \
      --ramdisk_offset 0x07c00000 \
      --os_version P \
      --os_patch_level 2016-11-05 \
      --ramdisk ramdisk.img \
      --output out/boot.img
    ;;
esac
xz out/boot.img
