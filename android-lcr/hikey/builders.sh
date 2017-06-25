# Early test
if [ ! -f build-configs/${BUILD_CONFIG_FILENAME} ]; then
  echo "No config file named ${BUILD_CONFIG_FILENAME} exists"
  echo "in android-build-configs.git"
  exit 1
fi

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

# Compress images
cd build/
out/host/linux-x86/bin/make_ext4fs -s -T -1 -S out/root/file_contexts -L data -l 1342177280 -a data out/userdata-4gb.img out/data
cd -

cd build/out
rm -f ramdisk.img
for image in "boot.img" "boot_fat.uefi.img" "system.img" "userdata.img" "userdata-4gb.img" "cache.img" "fip.bin" "l-loader.bin"; do
  ## there are the cases that fip.bin and l-loader.bin not generated
  ## so we add the check before run xz command
  if [ -f ${image} ]; then
    echo "Compressing ${image}"
    xz ${image}
  fi
done
cd -

rm -rf build/out/BUILD-INFO.txt
wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/hikey/build-info/template.txt -O build/out/BUILD-INFO.txt

# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
PUB_SRC=${PWD}/build/out
PUB_DEST=/android/${JOB_NAME}/${BUILD_NUMBER}
EOF

PUB_DEST=/android/${JOB_NAME}/${BUILD_NUMBER}
# Construct post-build-lava parameters
source build-configs/${BUILD_CONFIG_FILENAME}
cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEVICE_TYPE=${LAVA_DEVICE_TYPE:-${TARGET_PRODUCT}}
TARGET_PRODUCT=${TARGET_PRODUCT}
MAKE_TARGETS=${MAKE_TARGETS}
JOB_NAME=${JOB_NAME}
BUILD_NUMBER=${BUILD_NUMBER}
BUILD_URL=${BUILD_URL}
LAVA_SERVER=validation.linaro.org/RPC2/
IMAGE_EXTENSION=img.xz
FRONTEND_JOB_NAME=${JOB_NAME}
DOWNLOAD_URL=http://snapshots.linaro.org/${PUB_DEST}
CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template.json
SKIP_REPORT=false
EOF
