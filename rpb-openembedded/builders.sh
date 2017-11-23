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
pkg_list="android-tools-fsutils chrpath cpio diffstat gawk libmagickwand-dev libmath-prime-util-perl libsdl1.2-dev libssl-dev python-requests texinfo vim-tiny whiptail"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

set -ex

mkdir -p ${HOME}/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
chmod a+x ${HOME}/bin/repo
export PATH=${HOME}/bin:${PATH}

# initialize repo if not done already
if [ ! -e ".repo/manifest.xml" ]; then
   repo init -u https://github.com/96boards/oe-rpb-manifest.git -b ${MANIFEST_BRANCH_PREFIX}${MANIFEST_BRANCH}

   # link to shared downloads on persistent disk
   # our builds config is expecting downloads and sstate-cache, here.
   # DL_DIR = "${OEROOT}/sources/downloads"
   # SSTATE_DIR = "${OEROOT}/build/sstate-cache"
   mkdir -p ${HOME}/srv/oe/downloads ${HOME}/srv/oe/sstate-cache-${DISTRO}
   mkdir -p build
   ln -s ${HOME}/srv/oe/downloads
   ln -s ${HOME}/srv/oe/sstate-cache-${DISTRO} sstate-cache
fi

repo sync
cp .repo/manifest.xml source-manifest.xml
repo manifest -r -o pinned-manifest.xml
MANIFEST_COMMIT=$(cd .repo/manifests && git rev-parse --short HEAD)

# record changes since last build, if available
MANIFEST_URL=${BASE_URL}${PUB_DEST/\/${BUILD_NUMBER}\//\/latest\/}/pinned-manifest.xml
if wget -q ${MANIFEST_URL} -O pinned-manifest-latest.xml; then
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

# add useful debug info
cat conf/{site,auto}.conf

[ "${DISTRO}" = "rpb" ] && IMAGES+=" rpb-desktop-image rpb-desktop-image-lava"
[ "${DISTRO}" = "rpb-wayland" ] && IMAGES+=" rpb-weston-image rpb-weston-image-lava"
[ "${MACHINE}" = "am57xx-evm" ] && IMAGES="rpb-console-image"
if [ "${MACHINE}" = "hikey-32" ] ; then
    time bitbake_secondary_image --extra-machine hikey ${IMAGES}
else
    time bitbake ${IMAGES}
fi
DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE="| cut -d'=' -f2 | tr -d '"')

# Prepare files to publish
rm -f ${DEPLOY_DIR_IMAGE}/*.txt
find ${DEPLOY_DIR_IMAGE} -type l -delete
mv /srv/oe/{source,pinned}-manifest.xml ${DEPLOY_DIR_IMAGE}
cat ${DEPLOY_DIR_IMAGE}/pinned-manifest.xml

# FIXME: Sparse images here, until it gets done by OE
case "${MACHINE}" in
  juno|stih410-b2260|orangepi-i96)
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

# Move HiKey's bootloader related files into its own subdir
[ "${MACHINE}" = "hikey" ] && {
    rm -rf ${DEPLOY_DIR_IMAGE}/bootloader
    mkdir -p ${DEPLOY_DIR_IMAGE}/bootloader
    (cd ${DEPLOY_DIR_IMAGE} && mv fip.bin hisi-idt.py l-loader.bin nvme.img ptable-linux-*.img bootloader/)
}

# Create MD5SUMS file
find ${DEPLOY_DIR_IMAGE} -type f | xargs md5sum > MD5SUMS.txt
sed -i "s|${DEPLOY_DIR_IMAGE}/||" MD5SUMS.txt
mv MD5SUMS.txt ${DEPLOY_DIR_IMAGE}

# Build information
cat > ${DEPLOY_DIR_IMAGE}/HEADER.textile << EOF

h4. Reference Platform Build - CE OpenEmbedded

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Manifest URL: "https://github.com/96boards/oe-rpb-manifest.git":https://github.com/96boards/oe-rpb-manifest.git
* Manifest branch: ${MANIFEST_BRANCH_PREFIX}${MANIFEST_BRANCH}
* Manifest commit: "${MANIFEST_COMMIT}":https://github.com/96boards/oe-rpb-manifest/commit/${MANIFEST_COMMIT}
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
BOOT_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "boot-*-${MACHINE}-*-${BUILD_NUMBER}*.img" | xargs -r basename)
ROOTFS_EXT4_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-lava-${MACHINE}-*-${BUILD_NUMBER}.rootfs.ext4.gz" | xargs -r basename)
ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-lava-${MACHINE}-*-${BUILD_NUMBER}.rootfs.tar.xz" | xargs -r basename)
ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-lava-${MACHINE}-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "uImage-*-${MACHINE}-*-${BUILD_NUMBER}.bin" | xargs -r basename)
case "${MACHINE}" in
  am57xx-evm|juno)
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
SYSTEM_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_EXT4_IMG}
KERNEL_URL=${BASE_URL}${PUB_DEST}/${KERNEL_IMG}
DTB_URL=${BASE_URL}${PUB_DEST}/${DTB_IMG}
NFSROOTFS_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_TARXZ_IMG}
EOF
