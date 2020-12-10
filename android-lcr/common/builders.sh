#!/bin/bash

# Install needed packages
sudo apt-get update
sudo apt-get install -y bison git gperf libxml2-utils python-mako zip time python-requests genisoimage patch mtools python-wand rsync liblz4-tool lzop libssl-dev libdrm-intel1 python-pip python3-pip python-pyelftools python3-pyelftools python-crypto python3-crypto

wget -q \
  http://repo.linaro.org/ubuntu/linaro-overlay/pool/main/a/android-tools/android-tools-fsutils_4.2.2+git20130218-3ubuntu41+linaro1_amd64.deb \
  http://archive.ubuntu.com/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jre-headless_8u45-b14-1_amd64.deb \
  http://archive.ubuntu.com/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jre_8u45-b14-1_amd64.deb \
  http://archive.ubuntu.com/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jdk_8u45-b14-1_amd64.deb
sudo dpkg -i --force-all *.deb
rm -f *.deb

#change to use python3 by default
if ! python --version|grep 3; then
    sudo rm -fv /usr/bin/python && sudo ln -s /usr/bin/python3 /usr/bin/python
fi

# Install jinja2-cli and ruamel.yaml
pip install --user --force-reinstall jinja2-cli ruamel.yaml pycryptodome pycryptodomex
pip3 install --user --force-reinstall pycryptodome pycryptodomex ruamel.yaml Jinja2

# Set local configuration
git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"
java -version

BUILD_DIR=${BUILD_DIR:-${JOB_NAME}}
if [ ! -d "/home/buildslave/srv/${BUILD_DIR}" ]; then
  sudo mkdir -p /home/buildslave/srv/${BUILD_DIR}
  sudo chmod 777 /home/buildslave/srv/${BUILD_DIR}
fi
cd /home/buildslave/srv/${BUILD_DIR}

# temporary workaround to clean the workspace for android-cts and android-vts builds
if [ "X${BUILD_DIR}" == "Xandroid-cts" ] || [ "X${BUILD_DIR}" == "Xandroid-vts" ]; then
    rm -fr /home/buildslave/srv/${BUILD_DIR}/*
    rm -fr /home/buildslave/srv/${BUILD_DIR}/.repo
fi
# clean the out directory as this workspace is used accross multiple builds
rm -fr .repo-backup
[ -d "build/.repo" ] && mv -f build/.repo .repo-backup
rm -fr build/ && mkdir -p build/
[ -d "build/.repo-backup" ] && mv -f .repo-backup build/.repo
[ -d "build/.repo/local_manifests" ] && rm -fr build/.repo/local_manifests

# Download helper scripts (repo)
mkdir -p ${HOME}/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
chmod a+x ${HOME}/bin/*
export PATH=${HOME}/bin:${PATH}

# Install helper packages
rm -rf build-tools jenkins-tools build-configs build/bionic build/frameworks/base build/system/core build/device build/out build/android-patchsets build/kernel/ti/x15 build/kernel/hikey-linaro build/hardware/interfaces
rm -fr build/external/optee_test build/external/optee_client build/optee/optee_os build/optee/edk2 build/device/linaro/kmgk
rm -fr build/external/u-boot
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
export CONFIG=`base64 -w 0 config.txt`
export SKIP_LICENSE_CHECK=1

# still not in the build directory
