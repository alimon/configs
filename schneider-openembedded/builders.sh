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

#DEL mkdir -p ${HOME}/bin
#DEL curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
#DEL chmod a+x ${HOME}/bin/repo
#DEL export PATH=${HOME}/bin:${PATH}

# initialize repo if not done already
if [ ! -e ".repo/manifest.xml" ]; then
   #DEL repo init -u ${MANIFEST_URL} -b ${MANIFEST_BRANCH_PREFIX}${MANIFEST_BRANCH}

   # link to shared downloads on persistent disk
   # our builds config is expecting downloads and sstate-cache, here.
   # DL_DIR = "${OEROOT}/sources/downloads"
   # SSTATE_DIR = "${OEROOT}/build/sstate-cache"
   mkdir -p ${HOME}/srv/oe/downloads ${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH}
   #DEL mkdir -p build
   #DEL ln -s ${HOME}/srv/oe/downloads
   #DEL ln -s ${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH} sstate-cache
fi


#DEL if [ "${ghprbPullId}" ]; then
#DEL     echo "Applying Github pull-request #${ghprbPullId} from ${ghprbGhRepository}"
#DEL     sed -i -e "s|name=\"${ghprbGhRepository}\"|name=\"${ghprbGhRepository}\" revision=\"refs/pull/${ghprbPullId}/head\"|" .repo/manifest.xml
#DEL fi

#DEL repo sync
#DEL cp .repo/manifest.xml source-manifest.xml
#DEL repo manifest -r -o pinned-manifest.xml
#DEL MANIFEST_COMMIT=$(cd .repo/manifests && git rev-parse --short HEAD)

#DEL  record changes since last build, if available
#DEL if wget -q ${BASE_URL}${PUB_DEST/\/${BUILD_NUMBER}\//\/latest\/}/pinned-manifest.xml -O pinned-manifest-latest.xml; then
#DEL     repo diffmanifests ${PWD}/pinned-manifest-latest.xml ${PWD}/pinned-manifest.xml > manifest-changes.txt
#DEL else
#DEL     echo "latest build published does not have pinned-manifest.xml, skipping diff report"
#DEL fi

#DEL if [ -n "$GERRIT_PROJECT" ] && [ $GERRIT_EVENT_TYPE == "patchset-created" ]; then
#DEL     GERRIT_URL="http://${GERRIT_HOST}/${GERRIT_PROJECT}"
#DEL     cd `grep -rni $GERRIT_PROJECT\" .repo/manifest.xml | grep -Po 'path="\K[^"]*'`
#DEL     if git pull ${GERRIT_URL} ${GERRIT_REFSPEC} | grep -q "Automatic merge failed"; then
#DEL         git reset --hard
#DEL         echo "Error: *** Error patch merge failed"
#DEL         exit 1
#DEL     fi
#DEL     cd -
#DEL fi

git clone ${DISTRO_URL_BASE}/${DISTRO_DIR} -b ${MANIFEST_BRANCH}
cd ${DISTRO_DIR}
git submodule init
git submodule update

# the setup-environment will create auto.conf and site.conf
# make sure we get rid of old config.
# let's remove the previous TMPDIR as well.
# we want to preserve build/buildhistory though.
#DEL rm -rf conf build/conf build/tmp/

# Accept EULA if/when needed
#DEL export EULA_dragonboard410c=1
#DEL export EULA_stih410b2260=1
#DEL source setup-environment build
source sources/poky/oe-init-build-env  build-${MACHINE}/

ln -s ${HOME}/srv/oe/downloads
ln -s ${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH} sstate-cache

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

# allow the top level job to append to auto.conf
if [ -f ${WORKSPACE}/auto.conf ]; then
    cat ${WORKSPACE}/auto.conf >> conf/auto.conf
fi

# add useful debug info
cat conf/auto.conf

[ "${DISTRO}" = "rpb" ] && IMAGES+=" ${IMAGES_RPB}"
[ "${DISTRO}" = "rpb-wayland" ] && IMAGES+=" ${IMAGES_RPB_WAYLAND}"

# These machines only build the basic rpb-console-image
case "${MACHINE}" in
  am57xx-evm|intel-core2-32|intel-corei7-64)
     IMAGES="rpb-console-image"
     ;;
  rzn1d*)
    # Temporary sstate cleanup to force binaries to be re-generated each time
    set +e
    bitbake -c cleansstate u-boot-rzn1 u-boot-rzn1-spkg linux-rzn1
    set -e
    ;;
esac

time bitbake ${IMAGES}

DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE="| cut -d'=' -f2 | tr -d '"')

# Prepare files to publish
rm -f ${DEPLOY_DIR_IMAGE}/*.txt
find ${DEPLOY_DIR_IMAGE} -type l -delete
#DEL mv /srv/oe/{source,pinned}-manifest.xml ${DEPLOY_DIR_IMAGE}
#DEL cat ${DEPLOY_DIR_IMAGE}/pinned-manifest.xml

# FIXME: IMAGE_FSTYPES_remove doesn't work
rm -f ${DEPLOY_DIR_IMAGE}/*.rootfs.ext4 \
      ${DEPLOY_DIR_IMAGE}/*.rootfs.iso \
      ${DEPLOY_DIR_IMAGE}/*.iso \
      ${DEPLOY_DIR_IMAGE}/*.stimg

# FIXME: Sparse images here, until it gets done by OE
case "${MACHINE}" in
  soca9)
    # re-create the SoCA9 DTB with a shorter filename
    pushd ${DEPLOY_DIR_IMAGE}
    mv zImage-*snarc_${MACHINE}*_bestla_512m*.dtb zImage-snarc_${MACHINE}_qspi_micronN25Q_bestla_512m.dtb
    rm zImage-*snarc_${MACHINE}*_bestla_[12]G*.dtb
    rm zImage-*snarc_${MACHINE}*_freja_*.dtb
    popd
    ;;
  juno|stih410-b2260|orangepi-i96)
    ;;
  *)
    for rootfs in $(find ${DEPLOY_DIR_IMAGE} -type f -name *.rootfs.ext4.gz); do
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

h4. Reference Platform Build - CE OpenEmbedded

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
KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "zImage-*-rzn1*-*-${BUILD_NUMBER}.bin" | xargs -r basename)
case "${MACHINE}" in
  am57xx-evm)
    # LAVA image is too big for am57xx-evm
    ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
    # FIXME: several dtb files case
    ;;
  intel-core2-32|intel-corei7-64)
    # No LAVA testing on intel-core* machines
    ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.tar.xz" | xargs -r basename)
    ;;
  juno)
    # FIXME: several dtb files case
    ;;
  rzn1|rzn1d)
    ROOTFS_TAR_BZ2=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-rzn1*-*-${BUILD_NUMBER}.rootfs.tar.bz2" | xargs -r basename)
    ROOTFS_DEV_TAR_BZ2=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-dev-rzn1*-*-${BUILD_NUMBER}.rootfs.tar.bz2" | xargs -r basename)
    DTB_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "zImage-*-${MACHINE}*-bestla-*-${BUILD_NUMBER}.dtb" | xargs -r basename)
    ;;
  *)
    DTB_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "*-${MACHINE}-*-${BUILD_NUMBER}.dtb" | xargs -r basename)
    ;;
esac


# Note: the main job script allows to override the default value for
#       BASE_URL and PUB_DEST, typically used for OE RPB builds
cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
MANIFEST_COMMIT=${BUILD_NUMBER}
BOOT_URL=${BASE_URL}${PUB_DEST}/${BOOT_IMG}
ROOTFS_BUILD_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_EXT4_IMG}
ROOTFS_SPARSE_BUILD_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_IMG}
ROOTFS_DESKTOP_SPARSE_BUILD_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_DESKTOP_IMG}
SYSTEM_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_EXT4_IMG}
KERNEL_FIT_URL=${BASE_URL}${PUB_DEST}/fitImage-1.0-r0-rzn1-snarc.itb
KERNEL_ZIMAGE_URL=${BASE_URL}${PUB_DEST}/${KERNEL_IMG}
DTB_URL=${BASE_URL}${PUB_DEST}/${DTB_IMG}
NFSROOTFS_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_TAR_BZ2}
NFSROOTFS_DEV_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_DEV_TAR_BZ2}
RECOVERY_IMAGE_URL=${BASE_URL}${PUB_DEST}/juno-oe-uboot.zip
LXC_BOOT_IMG=${BOOT_IMG}
LXC_ROOTFS_IMG=$(basename ${ROOTFS_IMG} .gz)
DEVICE_TYPE=${MACHINE}
EOF
