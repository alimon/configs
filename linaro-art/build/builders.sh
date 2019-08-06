#!/bin/bash -xe

# Build scripts
ANDROID_BUILD_DIR="${HOME}/srv/${JOB_NAME}/android"
mkdir -p "${ANDROID_BUILD_DIR}"

ART_BUILD_SCRIPTS_DIR="${WORKSPACE}/art-build-scripts"
git clone https://android-git.linaro.org/git/linaro-art/art-build-scripts.git "${ART_BUILD_SCRIPTS_DIR}"
git -C "${ART_BUILD_SCRIPTS_DIR}" fetch --tags --progress origin "${ART_BUILD_SCRIPTS_REFSPEC}"
git -C "${ART_BUILD_SCRIPTS_DIR}" checkout "${ART_BUILD_SCRIPTS_REF}"

cd "${ART_BUILD_SCRIPTS_DIR}/jenkins"
./setup_host.sh
./setup_android.sh

cd "${ANDROID_BUILD_DIR}"
perl "${ART_BUILD_SCRIPTS_DIR}/jenkins/test_launcher.pl" \
  "${ART_BUILD_SCRIPTS_DIR}/jenkins/build_target.sh" --target arm_krait-eng
perl "${ART_BUILD_SCRIPTS_DIR}/jenkins/test_launcher.pl" \
  "${ART_BUILD_SCRIPTS_DIR}/jenkins/build_target.sh" --target armv8-eng

sudo apt-get update
sudo apt-get install -y python-requests

mkdir -p pub
mv *.tar.xz pub/
cp "${WORKSPACE}/"*.xml pub/
PUB_DEST="${PUB_DEST:-/android/${JOB_NAME}/${BUILD_NUMBER}}"

# Publish
test -d "${HOME}/bin" || mkdir "${HOME}/bin"
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O "${HOME}/bin/linaro-cp.py"
time python "${HOME}/bin/linaro-cp.py" \
  --manifest \
  --link-latest \
  --split-job-owner \
  --server "${PUBLISH_SERVER}" \
  ./pub/ \
  "${PUB_DEST}" \
  --include "^[^/]+[._](tar[^/]*|xml|txt)$" \
