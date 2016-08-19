# Build Android
rm -rf build/out build/android-patchsets build/device/linaro/hikey
mkdir -p build/
cd build/
wget https://dl.google.com/dl/android/aosp/linaro-hikey-20160226-67c37b1a.tgz
tar -xvf linaro-hikey-20160226-67c37b1a.tgz
yes "I ACCEPT" | ./extract-linaro-hikey.sh
cd -

build-tools/node/build us-east-1.ec2-git-mirror.linaro.org "${CONFIG}"
cp -a /home/buildslave/srv/${JOB_NAME}/build/out/*.json /home/buildslave/srv/${JOB_NAME}/build/out/*.xml ${WORKSPACE}/

# Compress images
cd build/
out/host/linux-x86/bin/make_ext4fs -s -T -1 -S out/root/file_contexts -L data -l 1342177280 -a data out/userdata-4gb.img out/data
cd -

cd build/out
rm -f ramdisk.img
for image in "boot.img" "boot_fat.uefi.img" "system.img" "userdata.img" "userdata-4gb.img" "cache.img"; do
  echo "Compressing ${image}"
  tar -Jcf ${image}.tar.xz ${image}
  rm -f ${image}
done
cd -

rm -rf build/out/BUILD-INFO.txt
wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr-member-hikey/build-info/template.txt -O build/out/BUILD-INFO.txt

# Publish binaries
PUB_DEST=/android/$JOB_NAME/$BUILD_NUMBER
time linaro-cp.py \
  --api_version 3 \
  --manifest \
  --no-build-info \
  --link-latest \
  --split-job-owner \
  build/out \
  ${PUB_DEST} \
  --include "^[^/]+[._](img[^/]*|tar[^/]*|xml|sh|config)$" \
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
IMAGE_EXTENSION=img.tar.xz
FRONTEND_JOB_NAME=${JOB_NAME}
DOWNLOAD_URL=${PUBLISH_SERVER}/${PUB_DEST}
CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/hikey/template.json
SKIP_REPORT=false
EOF

echo "Build finished"
