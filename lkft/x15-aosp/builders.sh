#!/bin/bash

export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8
export JENKINS_WORKSPACE=${WORKSPACE}

java -version

git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"

sudo apt-get -q=2 update
sudo apt-get -q=2 install -y gcc-4.9-multilib bison git gperf libxml2-utils python-mako zip time python-requests genisoimage patch mtools python-pip pxz zlib1g-dev

wget -q http://mirrors.kernel.org/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jre-headless_8u45-b14-1_amd64.deb \
  http://mirrors.kernel.org/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jre_8u45-b14-1_amd64.deb \
  http://mirrors.kernel.org/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jdk_8u45-b14-1_amd64.deb
sudo dpkg -i --force-all *.deb

# Install ruamel.yaml
pip install --user --force-reinstall ruamel.yaml
pip install --user --force-reinstall Jinja2

mkdir -p ${HOME}/bin ${WORKSPACE}/build/out
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
chmod a+x ${HOME}/bin/*
export PATH=${HOME}/bin:${PATH}

cd ~/srv/aosp-master/build/
rm -rf .repo/manifests* .repo/local_manifests*
repo init -u http://android.googlesource.com/platform/manifest -b master
if [ ! -z ${REFERENCE_BUILD_URL} ]; then
  cd .repo/manifests/
  wget ${REFERENCE_BUILD_URL}/pinned-manifest.xml -O default.xml
  cd ../../
fi
cd .repo/
rm -rf local_manifests
git clone git://android-git.linaro.org/platform/manifest.git -b x15-master local_manifests
cd ../

set -e

# delete any stale folder
rm -rf clang-src

repo sync -j16 -c

# build kernel
export PATH=~/srv/toolchain/gcc-linaro-7.2.1-2017.11-x86_64_arm-eabi/bin:$PATH
export CROSS_COMPILE=arm-eabi-
export ARCH=arm
cd kernel/ti/x15/
export KERNEL_DESCRIBE=$(git rev-parse --short HEAD)
export KERNELDIR=${PWD}
./ti_config_fragments/defconfig_builder.sh -t ti_sdk_am57x_android_release
make ti_sdk_am57x_android_release_defconfig
make -j$(nproc) zImage dtbs modules
cd ../../../
cp -vf kernel/ti/x15/arch/arm/boot/dts/ti/am57xx-beagle-x15-revc.dtb device/ti/beagle_x15-kernel/4.14/am57xx-beagle-x15-revc.dtb
cp -vf kernel/ti/x15/arch/arm/boot/zImage device/ti/beagle_x15-kernel/4.14/zImage

source build/envsetup.sh
lunch beagle_x15-userdebug
make -j$(nproc)
wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/hikey/build-info/aosp-master-template.txt -O ${PWD}/out/target/product/am57xevm/BUILD-INFO.txt

# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
PUB_DEST=android/lkft/${JOB_NAME}/${BUILD_NUMBER}
PUB_SRC=${PWD}/out/target/product/beagle_x15
PUB_EXTRA_INC=^[^/]+zip
EOF

rm -rf .repo/manifests .repo/local_manifests
rm -rf art/ dalvik/ kernel/ bionic/ developers/ libcore/ sdk/ bootable/ development/ libnativehelper/ system/ build/ device/ test/ build-info/ docs/ packages/ toolchain/ .ccache/ external/ pdk/ tools/ compatibility/ frameworks/ platform_testing/ vendor/ cts/ hardware/ prebuilts/ linaro* clang-src/ kernel/
rm -fr device/ti/beagle_x15-kernel/