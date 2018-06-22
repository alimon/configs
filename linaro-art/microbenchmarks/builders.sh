#!/bin/bash -xe

sudo apt-get update
sudo apt-get install -y python-requests

# Build scripts
ANDROID_BUILD_DIR="${HOME}/srv/${JOB_NAME}/android"
ART_BUILD_SCRIPTS_DIR="${WORKSPACE}/art-build-scripts"
git clone https://android-git.linaro.org/git/linaro-art/art-build-scripts.git ${ART_BUILD_SCRIPTS_DIR}

cd ${ART_BUILD_SCRIPTS_DIR}/jenkins
# Port forwarding magic to have access to Nexus devices
source /home/buildslave/srv/nexus-config
export ANDROID_SERIAL=${BULLHEAD}
./setup_host.sh
./setup_android.sh

cd ${ANDROID_BUILD_DIR}
alias python=python3
perl scripts/jenkins/test_launcher.pl \
  scripts/benchmarks/benchmarks_run_target.sh --skip-run true

readonly out_krait=out/target/product/arm_krait
readonly out_armv8=out/target/product/armv8
readonly out_host=out/host/linux-x86

tar -cJf test-arm-fs.txz ${out_host}/bin/ ${out_host}/framework/ ${out_krait}/data/ ${out_krait}/system/ ${out_krait}/dex_bootjars/system/framework/arm/boot.oat
tar -cJf test-armv8-fs.txz ${out_host}/bin/ ${out_host}/framework/ ${out_armv8}/data/ ${out_armv8}/system/ ${out_armv8}/dex_bootjars/system/framework/arm64/boot.oat

mkdir -p pub
mv ${WORKSPACE}/*.xml *.txz pub/
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
  --include "^[^/]+[._](img[^/]*|tar[^/]*|xml|sh|config|txz)$" \
  --include "^[BHi][^/]+txt$" \
  --include "^(MANIFEST|MD5SUMS|changelog.txt)$"

# Construct post-build-lava parameters
cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEVICE_TYPE=nexus5x
TARGET_PRODUCT=pixel
MAKE_TARGETS=droidcore
JOB_NAME=${JOB_NAME}
BUILD_NUMBER=${BUILD_NUMBER}
BUILD_URL=${BUILD_URL}
LAVA_SERVER=validation.linaro.org/RPC2/
GERRIT_CHANGE_NUMBER=${GERRIT_CHANGE_NUMBER}
GERRIT_PATCHSET_NUMBER=${GERRIT_PATCHSET_NUMBER}
GERRIT_CHANGE_URL=${GERRIT_CHANGE_URL}
GERRIT_CHANGE_ID=${GERRIT_CHANGE_ID}
FRONTEND_JOB_NAME=${JOB_NAME}
DOWNLOAD_URL=http://snapshots.linaro.org/android/$JOB_NAME/$BUILD_NUMBER
CUSTOM_JSON_URL=https://git.linaro.org/qa/test-plans.git/plain/android/nexus5x/microbenchmarks_32.yaml
SKIP_REPORT=true
QA_REPORTS_TOKEN=${QA_REPORTS_TOKEN}
EOF

