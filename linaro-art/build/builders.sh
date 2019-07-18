#!/bin/bash -xe

sudo apt-get update
sudo apt-get install -y python-requests

# Build scripts
ANDROID_BUILD_DIR="${HOME}/srv/${JOB_NAME}/android"

mkdir -p "${ANDROID_BUILD_DIR}"
cd "${ANDROID_BUILD_DIR}"

git config --global user.email "linaro-art-ci@linaro.org"
git config --global user.name "Linaro ART CI"

rm -f "${WORKSPACE}/"*.{txt,log,csv}

# Use the `master-art` short manifest for ART only dependencies.
repo init --depth=1 \
  -u https://android.googlesource.com/platform/manifest \
  -b master-art

( rm -rf .repo/local_manifests && \
  git clone ssh://git@dev-private-git.linaro.org/linaro-art/platform/manifest.git -b master-art \
  .repo/local_manifests )

repo sync -j10 --current-branch --force-sync --detach --force-remove-dirty

# build_target.sh & --skip-build on target_test.sh
repo download -c "linaro-art/art-build-scripts" 20281/23

if [[ -v GERRIT_CHANGE_NUMBER ]]; then
  repo download "$GERRIT_PROJECT" "$GERRIT_CHANGE_NUMBER/$GERRIT_PATCHSET_NUMBER"
fi

repo manifest -r -o "${WORKSPACE}/pinned-manifest.xml"

scripts/jenkins/test_launcher.pl scripts/jenkins/build_target.sh --target arm_krait-eng
scripts/jenkins/test_launcher.pl scripts/jenkins/build_target.sh --target armv8-eng

mkdir -p pub
mv *.tar.xz pub/
cp "${WORKSPACE}/*.xml" pub/
PUB_DEST=${PUB_DEST:-/android/${JOB_NAME}/${BUILD_NUMBER}}

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --manifest \
  --link-latest \
  --split-job-owner \
  --server ${PUBLISH_SERVER} \
  ./pub/ \
  ${PUB_DEST} \
  --include "^[^/]+[._](tar[^/]*|xml|txt)$" \
