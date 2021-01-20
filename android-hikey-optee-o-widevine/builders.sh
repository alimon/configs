#!/bin/bash

# Install needed packages
sudo apt-get update
sudo apt-get install -y bison git gperf libxml2-utils python-mako zip time python-requests genisoimage patch mtools python-wand rsync liblz4-tool lzop libssl-dev libdrm-intel1 python-pip python-pyelftools python3-pyelftools

wget -q \
	http://repo.linaro.org/ubuntu/linaro-overlay/pool/main/a/android-tools/android-tools-fsutils_4.2.2+git20130218-3ubuntu41+linaro1_amd64.deb \
	http://archive.ubuntu.com/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jre-headless_8u45-b14-1_amd64.deb \
	http://archive.ubuntu.com/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jre_8u45-b14-1_amd64.deb \
	http://archive.ubuntu.com/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jdk_8u45-b14-1_amd64.deb
sudo dpkg -i --force-all *.deb
rm -f *.deb

# Install jinja2-cli and ruamel.yaml
# pip install --user --force-reinstall jinja2-cli ruamel.yaml

# Set local configuration
git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"
java -version

# Download helper scripts (repo)
mkdir -p ${HOME}/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
chmod a+x ${HOME}/bin/*
export PATH=${HOME}/bin:${PATH}

set -e

cat << EOF > ${HOME}/.ssh/config
Host dev-private-review.linaro.org
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
EOF
chmod 0600 ${HOME}/.ssh/config

repo init -u https://android-git.linaro.org/git/platform/manifest.git -b android-8.1.0_r29 -g "default,-non-default,-device,hikey"
cd .repo
git clone https://android-git.linaro.org/git/platform/manifest.git -b linaro-oreo local_manifests
cd local_manifests
rm -f swg.xml
wget -q https://raw.githubusercontent.com/linaro-swg/optee_android_manifest/lcr-ref-hikey-o/swg.xml
cd ${WORKSPACE}

repo sync -j$(nproc)
./android-patchsets/hikey-o-workarounds
./android-patchsets/get-hikey-blobs
./android-patchsets/O-RLCR-PATCHSET
./android-patchsets/hikey-optee-o
./android-patchsets/hikey-optee-4.9
./android-patchsets/OREO-BOOTTIME-OPTIMIZATIONS-HIKEY
./android-patchsets/optee-master-workarounds
./android-patchsets/swg-mods-o

source ./build/envsetup.sh
lunch hikey-userdebug

make TARGET_BUILD_KERNEL=true TARGET_BOOTIMAGE_USE_FAT=true \
	CFG_SECURE_DATA_PATH=y CFG_SECSTOR_TA_MGMT_PTA=y CFG_TA_DYNLINK=y \
	TARGET_TEE_IS_OPTEE=true TARGET_BUILD_UEFI=true \
	TARGET_ENABLE_MEDIADRM_64=true

cd external
git clone ssh://lhg-gerrit-bot@dev-private-review.linaro.org:29418/widevine/optee-widevine-ref -b master
cd optee-widevine-ref/
if [ "${GERRIT_PROJECT}" == "widevine/optee-widevine-ref" ]; then
    git pull ssh://lhg-gerrit-bot@dev-private-review.linaro.org:29418/${GERRIT_PROJECT} ${GERRIT_REFSPEC}
fi
cd ../../

cd vendor
git clone ssh://lhg-gerrit-bot@dev-private-review.linaro.org:29418/widevine/android widevine -b mirrors/oc-mr1
cd widevine/
if [ "${GERRIT_PROJECT}" == "widevine/android" ]; then
    git pull ssh://lhg-gerrit-bot@dev-private-review.linaro.org:29418/${GERRIT_PROJECT} ${GERRIT_REFSPEC}
fi
cd ../../

cd external/optee-widevine-ref
mma TARGET_BUILD_KERNEL=true TARGET_BOOTIMAGE_USE_FAT=true \
        CFG_SECURE_DATA_PATH=y CFG_SECSTOR_TA_MGMT_PTA=y TARGET_TEE_IS_OPTEE=true \
        TARGET_BUILD_UEFI=true TARGET_ENABLE_MEDIADRM_64=true USE_TEST_KBOX=true
cd ../../

cd vendor/widevine
mma TARGET_BUILD_KERNEL=true TARGET_BOOTIMAGE_USE_FAT=true \
        CFG_SECURE_DATA_PATH=y CFG_SECSTOR_TA_MGMT_PTA=y TARGET_TEE_IS_OPTEE=true \
        TARGET_BUILD_UEFI=true TARGET_ENABLE_MEDIADRM_64=true
cd ../../
