#!/bin/bash

# Install needed packages
sudo apt-get update
sudo apt-get install -y bison git gperf libxml2-utils python-mako zip time python-requests genisoimage patch mtools python-wand rsync liblz4-tool lzop libssl-dev libdrm-intel1 python-pip

wget -q \
  http://repo.linaro.org/ubuntu/linaro-overlay/pool/main/a/android-tools/android-tools-fsutils_4.2.2+git20130218-3ubuntu41+linaro1_amd64.deb \
  http://old-releases.ubuntu.com/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jre-headless_8u45-b14-1_amd64.deb \
  http://old-releases.ubuntu.com/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jre_8u45-b14-1_amd64.deb \
  http://old-releases.ubuntu.com/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jdk_8u45-b14-1_amd64.deb
sudo dpkg -i --force-all *.deb
rm -f *.deb

# Install jinja2-cli and ruamel.yaml
pip install --user --force-reinstall jinja2-cli ruamel.yaml

# Set local configuration
git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"
java -version

BUILD_DIR=aosp-master/build
if [ ! -d "/home/buildslave/srv/${BUILD_DIR}" ]; then
  sudo mkdir -p /home/buildslave/srv/${BUILD_DIR}
  sudo chmod 777 /home/buildslave/srv/${BUILD_DIR}
fi
cd /home/buildslave/srv/${BUILD_DIR}

# Download helper scripts (repo)
mkdir -p ${HOME}/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
chmod a+x ${HOME}/bin/*
export PATH=${HOME}/bin:${PATH}

cd .repo
rm -rf local_manifests
cd -
repo init -u https://android.googlesource.com/platform/manifest  -b master

export AOSP_MASTER_BUILD=fail
repo sync -j$(nproc) -c -f
rm -rf build-info
source build/envsetup.sh
lunch db845c-userdebug
mma -j$(nproc) libGLES_mesa hwcomposer.drm gralloc.gbm

export AOSP_MASTER_BUILD=pass

pushd external/mesa3d
set +e
git remote rm upstream
set -e
git remote add upstream git://anongit.freedesktop.org/mesa/mesa
git fetch upstream 
git checkout ${GIT_COMMIT}
export AUTHOR_EMAIL_ADDRESS=$(git log --pretty=format:"%ae" HEAD -1)
export PATCH_SUBJECT=$(git log --pretty=format:"%s" HEAD -1)
popd

# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
AUTHOR_EMAIL_ADDRESS=${AUTHOR_EMAIL_ADDRESS}
PATCH_SUBJECT=${PATCH_SUBJECT}
AOSP_MASTER_BUILD=${AOSP_MASTER_BUILD}
EOF

set -ex
ln -sf /usr/bin/python prebuilts/build-tools/path/linux-x86/python
mma -j$(nproc) libGLES_mesa hwcomposer.drm gralloc.gbm TEMPORARY_DISABLE_PATH_RESTRICTIONS=true
