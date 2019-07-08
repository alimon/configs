#!/bin/bash

# Install needed packages
sudo apt-get update
sudo apt-get install -y bison git gperf libxml2-utils python-mako zip time python-requests genisoimage patch mtools python-wand rsync linaro-image-tools liblz4-tool lzop libssl-dev libdrm-intel1 python-pip

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

repo init -u https://android.googlesource.com/platform/manifest 
cd .repo
git clone https://android-git.linaro.org/git/platform/manifest.git .repo/local_manifests -b db845c
cd -

repo sync -j$(nproc) -c -f
lunch linaro_db845c-userdebug
make -j$(nproc)
cd out/target/product/linaro_db845c/

# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
PUB_DEST=96boards/dragonboard845c/linaro/aosp-master/${BUILD_NUMBER}
PUB_SRC=${PWD}/out/target/product/linaro_db845c/
PUB_EXTRA_INC=^[^/]+\.(dtb|dtbo|zip)$|MLO|vmlinux|System.map
EOF
