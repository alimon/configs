#!/bin/bash

set -e

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="python-requests chrpath gawk texinfo libsdl1.2-dev whiptail diffstat cpio libssl-dev android-tools-fsutils"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

set -ex

rm -rf oe-core
git clone --depth 1 -b ${BRANCH} https://github.com/openembedded/openembedded-core oe-core
git clone --depth 1 -b ${BRANCH} https://github.com/openembedded/bitbake oe-core/bitbake

COMMIT_OE_CORE=$(cd oe-core && git rev-parse --short HEAD)
COMMIT_BITBAKE=$(cd oe-core/bitbake && git rev-parse --short HEAD)

# make sure we get rid of old config.
# let's remove the previous TMPDIR as well.
# we want to preserve build/buildhistory though.
rm -rf conf tmp-*glibc

# build folder is outside of oe-core, so that we can clean them separately
source oe-core/oe-init-build-env build

# light customizations
cat << EOF >> conf/auto.conf
IMAGE_NAME_append = "-${BUILD_NUMBER}"
KERNEL_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
MODULE_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
MACHINE = "${MACHINE}"
INHERIT += "rm_work buildhistory image-buildinfo buildstats buildstats-summary"
BUILDHISTORY_COMMIT = "1"
EOF

cat << EOF >> conf/site.conf
SSTATE_DIR = "${HOME}/srv/oe/sstate-cache"
DL_DIR = "${HOME}/srv/oe/downloads"
EOF

# add useful debug info
cat conf/{site,auto}.conf

time bitbake ${IMAGES}
DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE="| cut -d'=' -f2 | tr -d '"')

# Prepare files to publish
rm -f ${DEPLOY_DIR_IMAGE}/*.txt
rm -rf ${DEPLOY_DIR_IMAGE}/bootloader
find ${DEPLOY_DIR_IMAGE} -type l -delete

# Create MD5SUMS file
(cd ${DEPLOY_DIR_IMAGE} && md5sum * > MD5SUMS.txt)

# Build information
cat > ${DEPLOY_DIR_IMAGE}/HEADER.textile << EOF

h4. OpenEmbedded Core Upstream Build

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Branch: ${BRANCH}
* OE Core commit: "${COMMIT_OE_CORE}":https://github.com/openembedded/openembedded-core/commit/${COMMIT_OE_CORE}
* Bitbake commit: "${COMMIT_BITBAKE}":https://github.com/openembedded/bitbake/commit/${COMMIT_BITBAKE}
EOF

# Ignore error as we always want to create post_build_lava_parameters
set +e

cat << EOF > ${WORKSPACE}/post_build_parameters
DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
EOF
