#!/bin/bash

set -xe

# workaround EDK2 is confused by the long path used during the build
# and truncate files name expected by VfrCompile
sudo mkdir -p /srv/oe
sudo chown buildslave:buildslave /srv/oe
cd /srv/oe

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    echo "Running cleanup_exit..."
}

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi

pkg_list=" python-pip coreutils gawk wget git-core diffstat unzip texinfo gcc-multilib build-essential chrpath socat cpio python python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping libsdl1.2-dev xterm android-tools-fsutils repo whiptail pxz locales libssl-dev android-tools-fsutils libarchive13 libgpgme11 libcurl4"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

sudo locale-gen en_US.UTF-8 && sudo update-locale LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Install ruamel.yaml
pip install --user --force-reinstall ruamel.yaml

set -ex

mkdir -p ${HOME}/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
chmod a+x ${HOME}/bin/repo
export PATH=${HOME}/bin:${PATH}

# initialize repo if not done already
if [ ! -e ".repo/manifest.xml" ]; then
   repo init -u https://github.com/OpenSourceFoundries/lmp-manifest

   # link to shared downloads on persistent disk
   # our builds config is expecting downloads and sstate-cache, here.
   # DL_DIR = "${OEROOT}/sources/downloads"
   # SSTATE_DIR = "${OEROOT}/build/sstate-cache"
   mkdir -p ${HOME}/srv/oe/downloads ${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH}
   mkdir -p build
   ln -s ${HOME}/srv/oe/downloads
   ln -s ${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH} sstate-cache
fi

repo sync
cp .repo/manifest.xml source-manifest.xml
repo manifest -r -o pinned-manifest.xml
MANIFEST_COMMIT=$(cd .repo/manifests && git rev-parse --short HEAD)

# the setup-environment will create auto.conf and site.conf
# make sure we get rid of old config.
# let's remove the previous TMPDIR as well.
# we want to preserve build/buildhistory though.
rm -rf conf build/conf build/tmp-*glibc/

MACHINE=hikey source setup-environment build

# use opensource OSF repository
cat << EOF >> conf/local.conf
OSF_LMP_GIT_URL = "github.com"
OSF_LMP_GIT_NAMESPACE = "opensourcefoundries/"
SOTA_CLIENT_PROV = "aktualizr-implicit-prov"
OSTREE_BRANCHNAME = "hikey-${BUILD_NUMBER}"
EOF

# add useful debug info
cat conf/{site,auto,local}.conf
cat ${distro_conf}
cat ${custom_kernel_conf}

time bitbake lmp-gateway-image

DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE="| cut -d'=' -f2 | tr -d '"')

# Prepare files to publish
rm -f ${DEPLOY_DIR_IMAGE}/*.txt
find ${DEPLOY_DIR_IMAGE} -type l -delete
cd ${DEPLOY_DIR_IMAGE}

otaimg=$(ls *.otaimg)
ext2simg -v ${otaimg} sparse-${otaimg}
rm -rf ${otaimg}

export REPO=${PWD}/ostree_repo
export OSTREE=../../../tmp*/sysroots-components/x86_64/ostree-native/usr/bin/ostree
BRANCHNAME=$(${OSTREE} refs --repo ${REPO})
UPDATE_SHA=$(${OSTREE} log --repo ${REPO}  ${BRANCHNAME}  | grep -m1 commit | cut  -f2 -d ' ')
tar -cJf ostree_repo.tar.xz ostree_repo/
rm -rf ostree_repo

# Delete bootloader as it has a broken ptable
rm -rf bootloader
cd -

mv /srv/oe/{source,pinned}-manifest.xml ${DEPLOY_DIR_IMAGE}
cat ${DEPLOY_DIR_IMAGE}/pinned-manifest.xml

# Create MD5SUMS file
find ${DEPLOY_DIR_IMAGE} -type f | xargs md5sum > MD5SUMS.txt
sed -i "s|${DEPLOY_DIR_IMAGE}/||" MD5SUMS.txt
mv MD5SUMS.txt ${DEPLOY_DIR_IMAGE}

BOOT_IMG="$(find ${DEPLOY_DIR_IMAGE} -type f -name "boot-*.img" | sort | xargs -r basename)"
ROOTFS_IMG="$(find ${DEPLOY_DIR_IMAGE} -type f -name "sparse-lmp-gateway-image*.otaimg" | xargs -r basename)"
BASE_URL="http://snapshots.linaro.org"


cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
BOOT_URL=${BASE_URL}/${PUB_DEST}/${BOOT_IMG}
SYSTEM_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_IMG}
UPDATE_SHA=${UPDATE_SHA}
EOF

cat << EOF > ${WORKSPACE}/ota_params
BUILD_URL=${BASE_URL}/${PUB_DEST}/
EOF

# Build information
cat > ${DEPLOY_DIR_IMAGE}/HEADER.textile << EOF


h4. OSF Linux Microplatform

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
EOF
