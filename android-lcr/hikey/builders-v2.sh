# Early test
if [ ! -f build-configs/${BUILD_CONFIG_FILENAME} ]; then
  echo "No config file named ${BUILD_CONFIG_FILENAME} exists"
  echo "in android-build-configs.git"
  exit 1
fi

source build-configs/${BUILD_CONFIG_FILENAME}

# Clean android-patchsets and repositories in device
rm -rf build/out build/android-patchsets build/device

mkdir -p build/
cd build/
wget https://dl.google.com/dl/android/aosp/linaro-hikey-20170523-4b9ebaff.tgz
tar -xvf linaro-hikey-20170523-4b9ebaff.tgz
yes "I ACCEPT" | ./extract-linaro-hikey.sh
cd -

# Build Android
build-tools/node/build us-east-1.ec2-git-mirror.linaro.org "${CONFIG}"
cp -a /home/buildslave/srv/${BUILD_DIR}/build/out/*.json /home/buildslave/srv/${BUILD_DIR}/build/out/*.xml ${WORKSPACE}/

# publish fip.bin and l-loader.bin
cp -v /home/buildslave/srv/${BUILD_DIR}/build/out/dist/fip.bin \
      /home/buildslave/srv/${BUILD_DIR}/build/out/dist/l-loader.bin build/out/ || true

cd build/out
for image in "boot.img" "boot_fat.uefi.img" "system.img" "userdata.img" "userdata-4gb.img" "cache.img" "fip.bin" "l-loader.bin" "vendor.img"; do
  ## there are the cases that fip.bin and l-loader.bin not generated
  ## so we add the check before run xz command
  if [ -f ${image} ]; then
    echo "Compressing ${image}"
    xz ${image}
  fi
done
cd -

if [ "X${BUILD_VENDOR_FOR_4_4}" = "Xtrue" ]; then
    cd build/
    source build/envsetup.sh
    lunch hikey-userdebug
    rm -rf out/target/product/hikey
    make vendorimage TARGET_KERNEL_USE=4.4
    cp out/target/product/hikey/vendor.img out/vendor-4.4.img
    xz out/vendor-4.4.img
    cd -
fi

rm -rf build/out/BUILD-INFO.txt
wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/hikey/build-info/aosp-master-template.txt -O build/out/BUILD-INFO.txt

# Delete sources after build to save space
cd build
rm -rf art/ dalvik/ kernel/ bionic/ developers/ libcore/ sdk/ bootable/ development/ libnativehelper/ system/ build/ device/ test/ build-info/ docs/ packages/ toolchain/ .ccache/ external/ pdk/ tools/ compatibility/ frameworks/ platform_testing/ vendor/ cts/ hardware/ prebuilts/ linaro*
cd -

# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
PUB_SRC=${PWD}/build/out
PUB_DEST=/android/${JOB_NAME}/${BUILD_NUMBER}
EOF

PUB_DEST=/android/${JOB_NAME}/${BUILD_NUMBER}
# Construct post-build-lava parameters
cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEVICE_TYPE=hi6220-hikey
TARGET_PRODUCT=${TARGET_PRODUCT}
MAKE_TARGETS=${MAKE_TARGETS}
JOB_NAME=${JOB_NAME}
BUILD_NUMBER=${BUILD_NUMBER}
BUILD_URL=${BUILD_URL}
LAVA_SERVER=lkft.validation.linaro.org/RPC2/
IMAGE_EXTENSION=img.xz
FRONTEND_JOB_NAME=${JOB_NAME}
DOWNLOAD_URL=http://snapshots.linaro.org/${PUB_DEST}
CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey-v2/template.yaml
SKIP_REPORT=false
CTS_PKG_URL=${CTS_PKG_URL}
VTS_PKG_URL=${VTS_PKG_URL}
ANDROID_VERSION_SUFFIX=${ANDROID_VERSION_SUFFIX}
PLAN_CHANGE=${PLAN_CHANGE}
PLAN_WEEKLY=${PLAN_WEEKLY}
EOF
