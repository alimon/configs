# Build u-boot, MLO and dtb
if [ ! -e gcc-linaro-arm-none-eabi-4.8-2014.04_linux ]; then
  wget -q https://releases.linaro.org/archive/14.04/components/toolchain/binaries/gcc-linaro-arm-none-eabi-4.8-2014.04_linux.tar.bz2
  tar -xvf gcc-linaro-arm-none-eabi-4.8-2014.04_linux.tar.bz2
fi
export PATH=${PWD}/gcc-linaro-arm-none-eabi-4.8-2014.04_linux/bin/:${PATH}
export CROSS_COMPILE="arm-none-eabi-"
export ARCH=arm

rm -rf u-boot linux
git clone --depth=1 git://git.ti.com/android-sdk/u-boot.git u-boot -b p-ti-u-boot-2016.05
cd u-boot
make am57xx_evm_nodt_defconfig
make -j"$(nproc)"
cd -

# Build Kernel
git clone --depth=1 git://git.ti.com/android-sdk/kernel-omap.git linux -b p-ti-lsk-android-linux-4.4.y
cd linux
ti_config_fragments/defconfig_builder.sh -t ti_sdk_am57x_android_release
make ti_sdk_am57x_android_release_defconfig
make -j"$(nproc)" zImage
make am57xx-evm-reva3.dtb
cd -

# Build Android
build-tools/node/build us-east-1.ec2-git-mirror.linaro.org "${CONFIG}"
cp -a /home/buildslave/srv/${BUILD_DIR}/build/out/*.json /home/buildslave/srv/${BUILD_DIR}/build/out/*.xml ${WORKSPACE}/

# Copy dtb mlo uboot to out location
cp /home/buildslave/srv/${BUILD_DIR}/u-boot/MLO /home/buildslave/srv/${BUILD_DIR}/u-boot/u-boot /home/buildslave/srv/${BUILD_DIR}/linux/arch/arm/boot/dts/*.dtb /home/buildslave/srv/${BUILD_DIR}/build/out/

# Publish binaries
PUB_DEST=/android/${JOB_NAME}/${BUILD_NUMBER}
time linaro-cp.py \
  --api_version 3 \
  --manifest \
  --no-build-info \
  --link-latest \
  --split-job-owner \
  build/out \
  ${PUB_DEST} \
  --include "^[^/]+[._](img[^/]*|tar[^/]*|xml|sh|config|u-boot|MLO|dtb)$" \
  --include "^[BHi][^/]+txt$" \
  --include "^(MANIFEST|MD5SUMS|changelog.txt)$"

# Construct post-build-lava parameters
if [ -f build-configs/${BUILD_CONFIG_FILENAME} ]; then
  source build-configs/${BUILD_CONFIG_FILENAME}
else
  echo "No config file named ${BUILD_CONFIG_FILENAME} exists"
  echo "in android-build-configs.git"
  exit 1
fi

cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEVICE_TYPE=${LAVA_DEVICE_TYPE:-${TARGET_PRODUCT}}
TARGET_PRODUCT=${TARGET_PRODUCT}
MAKE_TARGETS=${MAKE_TARGETS}
JOB_NAME=${JOB_NAME}
BUILD_NUMBER=${BUILD_NUMBER}
BUILD_URL=${BUILD_URL}
LAVA_SERVER=validation.linaro.org/RPC2/
IMAGE_EXTENSION=img
FRONTEND_JOB_NAME=${JOB_NAME}
DOWNLOAD_URL=${PUBLISH_SERVER}/${PUB_DEST}
CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/x15/template.json
SKIP_REPORT=false
EOF

echo "Build finished"
