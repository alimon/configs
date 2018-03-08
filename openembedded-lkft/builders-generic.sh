#!/bin/bash

set -e

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
pkg_list="python-pip android-tools-fsutils chrpath cpio diffstat gawk libmagickwand-dev libmath-prime-util-perl libsdl1.2-dev libssl-dev python-requests texinfo vim-tiny whiptail"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

# Install ruamel.yaml
pip install --user --force-reinstall ruamel.yaml

set -ex

mkdir -p ${HOME}/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
chmod a+x ${HOME}/bin/repo
export PATH=${HOME}/bin:${PATH}

# initialize repo if not done already
if [ ! -e ".repo/manifest.xml" ]; then
   repo init -u ${MANIFEST_URL} -b ${MANIFEST_BRANCH_PREFIX}${MANIFEST_BRANCH}

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

# record changes since last build, if available
if wget -q ${BASE_URL}${PUB_DEST/\/${BUILD_NUMBER}\//\/latest\/}/pinned-manifest.xml -O pinned-manifest-latest.xml; then
    repo diffmanifests ${PWD}/pinned-manifest-latest.xml ${PWD}/pinned-manifest.xml > manifest-changes.txt
else
    echo "latest build published does not have pinned-manifest.xml, skipping diff report"
fi

# the setup-environment will create auto.conf and site.conf
# make sure we get rid of old config.
# let's remove the previous TMPDIR as well.
# we want to preserve build/buildhistory though.
rm -rf conf build/conf build/tmp-*glibc/

# Accept EULA if/when needed
export EULA_dragonboard410c=1
export EULA_stih410b2260=1
source setup-environment build

# Add job BUILD_NUMBER to output files names
cat << EOF >> conf/auto.conf
IMAGE_NAME_append = "-${BUILD_NUMBER}"
KERNEL_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
MODULE_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
DT_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
BOOT_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
EOF

# get build stats to make sure that we use sstate properly
cat << EOF >> conf/auto.conf
INHERIT += "buildstats buildstats-summary"
EOF

### FIXME LKFT Linux Generic Specific:
# Set the kernel to use
distro_conf=$(find ../layers/meta-rpb/conf/distro -name rpb.inc)
cat << EOF >> ${distro_conf}
PREFERRED_PROVIDER_virtual/kernel = "linux-generic"
EOF

# Set the image types to use
cat << EOF >> ${distro_conf}
IMAGE_FSTYPES_remove = "ext4 iso wic"
EOF

# Include additional recipes in the image
[ "${MACHINE}" = "am57xx-evm" -o "${MACHINE}" = "stih410-b2260" ] || extra_pkgs="numactl"
cat << EOF >> conf/local.conf
CORE_IMAGE_BASE_INSTALL_append = " kernel-selftests kselftests-mainline kselftests-next libhugetlbfs-tests ltp ${extra_pkgs}"
CORE_IMAGE_BASE_INSTALL_append = " python python-misc python-modules python-numpy python-pexpect python-pyyaml"
CORE_IMAGE_BASE_INSTALL_append = " git parted packagegroup-core-buildessential packagegroup-core-tools-debug tzdata"
EOF

# Override cmdline
cat << EOF >> conf/local.conf
CMDLINE_remove = "quiet"
EOF

# Remove recipes:
# - docker to reduce image size
cat << EOF >> conf/local.conf
RDEPENDS_packagegroup-rpb_remove = "docker"
EOF

cat << EOF >> conf/local.conf
DEFAULTTUNE_intel-core2-32 = "core2-64"
SERIAL_CONSOLES_remove_intel-core2-32 = "115200;ttyPCH0"
SERIAL_CONSOLES_append_dragonboard-410c = " 115200;ttyMSM1"
SERIAL_CONSOLES_append_hikey = " 115200;ttyAMA2"
EOF

custom_kernel_conf=$(find ../layers/meta-96boards/recipes-kernel -name custom-kernel-info.inc)
cat << EOF > ${custom_kernel_conf}
BASEPV = "4.16"
KERNEL_COMMIT = "${KERNEL_COMMIT}"
KERNEL_REPO = "${KERNEL_REPO/http*:/git:}"
KERNEL_BRANCH = "${KERNEL_BRANCH}"
KERNEL_CONFIG_aarch64 = "${KERNEL_CONFIG}"
KERNEL_CONFIG_arm = "${KERNEL_CONFIG}"
KERNEL_CONFIG_x86-64 = "${KERNEL_CONFIG}"
EOF
###

# add useful debug info
cat conf/{site,auto,local}.conf
cat ${distro_conf}
cat ${custom_kernel_conf}

[ "${DISTRO}" = "rpb" ] && IMAGES+=" ${IMAGES_RPB}"
[ "${DISTRO}" = "rpb-wayland" ] && IMAGES+=" ${IMAGES_RPB_WAYLAND}"
[ "${MACHINE}" = "am57xx-evm" ] && IMAGES="rpb-console-image"

time bitbake ${IMAGES}

DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE="| cut -d'=' -f2 | tr -d '"')

# Prepare files to publish
rm -f ${DEPLOY_DIR_IMAGE}/*.txt
find ${DEPLOY_DIR_IMAGE} -type l -delete
mv /srv/oe/{source,pinned}-manifest.xml ${DEPLOY_DIR_IMAGE}
cat ${DEPLOY_DIR_IMAGE}/pinned-manifest.xml

# FIXME: IMAGE_FSTYPES_remove doesn't work
rm -f ${DEPLOY_DIR_IMAGE}/*.rootfs.ext4 \
      ${DEPLOY_DIR_IMAGE}/*.rootfs.iso \
      ${DEPLOY_DIR_IMAGE}/*.rootfs.wic \
      ${DEPLOY_DIR_IMAGE}/*.stimg

# FIXME: Sparse images here, until it gets done by OE
case "${MACHINE}" in
  juno|stih410-b2260|orangepi-i96|intel-core2-32)
    ;;
  *)
    for rootfs in ${DEPLOY_DIR_IMAGE}/*.rootfs.ext4.gz; do
      gunzip -k ${rootfs}
      sudo ext2simg -v ${rootfs%.gz} ${rootfs%.ext4.gz}.img
      rm -f ${rootfs%.gz}
      gzip -9 ${rootfs%.ext4.gz}.img
    done
    ;;
esac

# Create MD5SUMS file
find ${DEPLOY_DIR_IMAGE} -type f | xargs md5sum > MD5SUMS.txt
sed -i "s|${DEPLOY_DIR_IMAGE}/||" MD5SUMS.txt
mv MD5SUMS.txt ${DEPLOY_DIR_IMAGE}

# Build information
cat > ${DEPLOY_DIR_IMAGE}/HEADER.textile << EOF

h4. LKFT Generic Linux - OpenEmbedded

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Manifest URL: "${MANIFEST_URL}":${MANIFEST_URL}
* Manifest branch: ${MANIFEST_BRANCH_PREFIX}${MANIFEST_BRANCH}
* Manifest commit: "${MANIFEST_COMMIT}":${MANIFEST_URL/.git/\/commit}/${MANIFEST_COMMIT}
EOF

if [ -e "/srv/oe/manifest-changes.txt" ]; then
  # the space after pre.. tag is on purpose
  cat > ${DEPLOY_DIR_IMAGE}/README.textile << EOF

h4. Manifest changes

pre.. 
EOF
  cat /srv/oe/manifest-changes.txt >> ${DEPLOY_DIR_IMAGE}/README.textile
  mv /srv/oe/manifest-changes.txt ${DEPLOY_DIR_IMAGE}
fi

# Need different files for each machine
BOOT_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "boot-*-${MACHINE}-*-${BUILD_NUMBER}*.img" | sort | xargs -r basename)
ROOTFS_EXT4_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-test-${MACHINE}-*-${BUILD_NUMBER}.rootfs.ext4.gz" | xargs -r basename)
ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-test-${MACHINE}-*-${BUILD_NUMBER}.rootfs.tar.xz" | xargs -r basename)
ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-test-${MACHINE}-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
ROOTFS_DESKTOP_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-desktop-image-test-${MACHINE}-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "uImage-*-${MACHINE}-*-${BUILD_NUMBER}.bin" | xargs -r basename)
case "${MACHINE}" in
  am57xx-evm)
    # LAVA image is too big for am57xx-evm
    ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
    # FIXME: several dtb files case
    ;;
  juno)
    # FIXME: several dtb files case
    ;;
  *)
    DTB_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "*-${MACHINE}-*-${BUILD_NUMBER}.dtb" | xargs -r basename)
    ;;
esac

# Note: the main job script allows to override the default value for
#       BASE_URL and PUB_DEST, typically used for OE RPB builds
cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
MANIFEST_COMMIT=${MANIFEST_COMMIT}
BOOT_URL=${BASE_URL}${PUB_DEST}/${BOOT_IMG}
ROOTFS_BUILD_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_EXT4_IMG}
ROOTFS_SPARSE_BUILD_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_IMG}
ROOTFS_DESKTOP_SPARSE_BUILD_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_DESKTOP_IMG}
SYSTEM_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_EXT4_IMG}
KERNEL_URL=${BASE_URL}${PUB_DEST}/${KERNEL_IMG}
DTB_URL=${BASE_URL}${PUB_DEST}/${DTB_IMG}
NFSROOTFS_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_TARXZ_IMG}
RECOVERY_IMAGE_URL=${BASE_URL}${PUB_DEST}/juno-oe-uboot.zip
LXC_BOOT_IMG=${BOOT_IMG}
LXC_ROOTFS_IMG=$(basename ${ROOTFS_IMG} .gz)
EOF
