# Build Android
repo init -u ${ANDROID_MANIFEST_URL} -b ${MANIFEST_BRANCH}
repo sync -j"$(nproc)" -c
source build/envsetup.sh
lunch ${LUNCH_TARGET}
make -j"$(nproc)"

# Publish binaries
PUB_DEST=/android/${JOB_NAME}/${BUILD_NUMBER}/${LUNCH_TARGET}
time linaro-cp.py \
  --api_version 3 \
  --manifest \
  --no-build-info \
  --link-latest \
  --split-job-owner \
  ${ANDROID_PRODUCT_OUT} \
  ${PUB_DEST} \
  --include "^[^/]+[._](img[^/]*|tar[^/]*|xml|sh|config)$" \
  --include "^[BHi][^/]+txt$" \
  --include "^(MANIFEST|MD5SUMS|changelog.txt)$"

echo "Build finished"
