# Early test

if [ ! -f build-configs/${BUILD_CONFIG_FILENAME} ]; then
  echo "No config file named ${BUILD_CONFIG_FILENAME} exists"
  echo "in android-build-configs.git"
  exit 1
fi

# Clean android-patchsets and repositories in device
rm -rf build/out build/android-patchsets build/device build/build-info
rm -fr build/external/u-boot
mkdir -p build

# Build Android
build-tools/node/build us-east-1.ec2-git-mirror.linaro.org "${CONFIG}"
cp -a /home/buildslave/srv/${BUILD_DIR}/build/out/*.json /home/buildslave/srv/${BUILD_DIR}/build/out/*.xml ${WORKSPACE}/

# Delete sources after build to save space
cd build
rm -rf art/ dalvik/ kernel/ bionic/ developers/ libcore/ sdk/ bootable/ development/ libnativehelper/ system/ build/ device/ test/ build-info/ docs/ packages/ toolchain/ .ccache/ external/ pdk/ tools/ compatibility/ frameworks/ platform_testing/ vendor/ cts/ hardware/ prebuilts/ linaro*
cd -

# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
PUB_SRC=${PWD}/build/out
PUB_DEST=/android/${JOB_NAME}/${BUILD_NUMBER}
PUB_EXTRA_INC=^[^/]+[._](itb|dtb)$|MLO
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
LAVA_SERVER=${LAVA_SERVER:-lkft.validation.linaro.org/RPC2/}
IMAGE_EXTENSION=img
FRONTEND_JOB_NAME=${JOB_NAME}
DOWNLOAD_URL=http://snapshots.linaro.org/${PUB_DEST}
SKIP_REPORT=false
CTS_PKG_URL=${CTS_PKG_URL}
VTS_PKG_URL=${VTS_PKG_URL}
ANDROID_VERSION_SUFFIX=${ANDROID_VERSION_SUFFIX}
KERNEL_DESCRIBE=${KERNEL_DESCRIBE}
PLAN_CHANGE=${PLAN_CHANGE}
PLAN_WEEKLY=${PLAN_WEEKLY}
EOF
