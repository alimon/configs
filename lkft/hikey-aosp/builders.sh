#!/bin/bash

set -ex

git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="python-pip"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

# Install ruamel.yaml
pip install --user --force-reinstall ruamel.yaml

git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9
mkdir -p clang
cd clang
wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/master/${TOOLCHAIN}.tar.gz
tar -xf ${TOOLCHAIN}.tar.gz
cd -
export PATH=${PWD}/aarch64-linux-android-4.9/bin/:${PWD}/clang/bin/:${PATH}


# Enable VFB locally until the patch is merged
if echo "${JOB_NAME}" | grep "4.14" ;then
   CMD="androidboot.console=ttyFIQ0 androidboot.hardware=hikey firmware_class.path=/system/etc/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug video=vfb:640x480-32@30 vfb.videomemorysize=3145728"
else
   CMD="androidboot.console=ttyFIQ0 androidboot.hardware=hikey firmware_class.path=/system/etc/firmware efi=noruntime printk.devkmsg=on buildvariant=userdebug"
fi


# Need to use TI specific bluetooth driver
if [ "${JOB_NAME}" = "lkft-hikey-android-8.0-4.9" ]; then
    git fetch ssh://vishal.bhoj@android-review.linaro.org:29418/kernel/hikey-linaro refs/changes/97/18097/1 && git cherry-pick FETCH_HEAD
fi

export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-android-
make ARCH=arm64 hikey_defconfig
make ARCH=arm64 CC=clang HOSTCC=clang -j$(nproc) -s Image-dtb

wget -q https://android-git.linaro.org/platform/system/core.git/plain/mkbootimg/mkbootimg -O mkbootimg
wget -q ${REFERENCE_BUILD_URL}/ramdisk.img -O ramdisk.img

mkdir -p out
python mkbootimg \
  --kernel ${PWD}/arch/arm64/boot/Image-dtb \
  --cmdline console="${CMD}" \
  --os_version O \
  --os_patch_level 2016-11-05 \
  --ramdisk ramdisk.img \
  --output out/boot.img
xz out/boot.img
