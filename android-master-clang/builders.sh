#!/bin/bash
export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8

export BUILD_CONFIG_FILENAME=hikey-aosp-master-clang
export PATH=$PATH:/home/buildslave/bin/

# Install needed packages
sudo apt-get -q=2 update
sudo apt-get -q=2 install -y bison git gperf libxml2-utils python-mako zip time python-requests genisoimage patch mtools python-wand rsync pxz gawk

wget -q \
  http://repo.linaro.org/ubuntu/linaro-overlay/pool/main/a/android-tools/android-tools-fsutils_4.2.2+git20130218-3ubuntu41+linaro1_amd64.deb
sudo dpkg -i --force-all *.deb
rm -f *.deb

# Set local configuration
git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"
java -version

# clean up files from old build
rm -rf build/prebuilts/clang

# Install helper packages
rm -rf build-tools jenkins-tools build-configs build/out build/android-patchsets
git clone --depth 1 https://git.linaro.org/infrastructure/linaro-android-build-tools.git build-tools
git clone --depth 1 https://git.linaro.org/infrastructure/linaro-jenkins-tools.git jenkins-tools
git clone --depth 1 http://android-git.linaro.org/git/android-build-configs.git build-configs

set -xe
# Define job configuration's repo
export BUILD_CONFIG_FILENAME=${BUILD_CONFIG_FILENAME:-${JOB_NAME#android-*}}
cat << EOF > config.txt
BUILD_CONFIG_REPO=http://android-git.linaro.org/git/android-build-configs.git
BUILD_CONFIG_BRANCH=master
EOF
echo config.txt
export CONFIG=$(base64 -w 0 config.txt)
export SKIP_LICENSE_CHECK=1

# Build Android
rm -rf build/out build/android-patchsets build/device/linaro/hikey
mkdir -p build/
cd build/
wget -q https://dl.google.com/dl/android/aosp/linaro-hikey-20170523-4b9ebaff.tgz
tar -xvf linaro-hikey-20170523-4b9ebaff.tgz
yes "I ACCEPT" | ./extract-linaro-hikey.sh
cd -

build-tools/node/build us-east-1.ec2-git-mirror.linaro.org "${CONFIG}"
cp -a /home/buildslave/workspace/android-master-clang/build/out/*.xml /home/buildslave/workspace/android-master-clang/build/out/*.xml ${WORKSPACE}/

cd build/out
rm -f ramdisk.img
for image in "boot.img" "boot_fat.uefi.img" "system.img" "userdata.img" "cache.img"; do
  echo "Compressing ${image}"
  pxz ${image}
done
cd -

rm -rf build/out/BUILD-INFO.txt
wget -q https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/hikey/build-info/template.txt -O build/out/BUILD-INFO.txt

cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEVICE_TYPE=hikey
TARGET_PRODUCT=hikey
MAKE_TARGETS=droidcore
JOB_NAME=${JOB_NAME}
BUILD_NUMBER=${BUILD_NUMBER}
IMAGE_EXTENSION=img.xz
BUILD_URL=${BUILD_URL}
LAVA_SERVER=validation.linaro.org/RPC2/
IMAGE_EXTENSION=img.xz
FRONTEND_JOB_NAME=${JOB_NAME}
DOWNLOAD_URL=http://snapshots.linaro.org/android/${JOB_NAME}/${BUILD_NUMBER}/
CUSTOM_JSON_URL=https://git.linaro.org/ci/job/configs.git/plain/android-master-clang/lava-job-definitions/boottime-android-master-clang.yaml
EOF

echo "Build finished"
