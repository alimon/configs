build-tools/node/build us-east-1.ec2-git-mirror.linaro.org "${CONFIG}"
cp -a /home/buildslave/srv/${BUILD_DIR}/build/out/*.xml /home/buildslave/srv/${BUILD_DIR}/build/out/*.json ${WORKSPACE}/

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
CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/blob_plain/HEAD:/android/lcr-member-fvp-m/template.json
DEVICE_TYPE=${LAVA_DEVICE_TYPE:-${TARGET_PRODUCT}}
TARGET_PRODUCT=${TARGET_PRODUCT}
MAKE_TARGETS=${MAKE_TARGETS}
JOB_NAME=${JOB_NAME}
BUILD_NUMBER=${BUILD_NUMBER}
BUILD_URL=${BUILD_URL}
LAVA_SERVER=validation.linaro.org/RPC2/
LAVA_STREAM=${BUNDLE_STREAM_NAME}
BUNDLE_STREAM_NAME=${BUNDLE_STREAM_NAME}
FRONTEND_JOB_NAME=${JOB_NAME}
SKIP_REPORT=false
EOF
