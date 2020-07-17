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
pkg_list="android-tools-fsutils chrpath cpio diffstat gawk libmagickwand-dev libmath-prime-util-perl libsdl1.2-dev libssl-dev python-crypto python3-crypto python-requests texinfo vim-tiny whiptail"
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

# Some proprietary code is on lhg-review.org server and dev-private-review server
cat << EOF > ${HOME}/lhg-review.sshconfig
Host lhg-review.linaro.org
    User lhg-gerrit-bot
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
Host dev-private-review.linaro.org
    User lhg-gerrit-bot
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
EOF
chmod 0600 ${HOME}/lhg-review.sshconfig

repo sync
cp .repo/manifest.xml source-manifest.xml
repo manifest -r -o pinned-manifest.xml
MANIFEST_COMMIT=$(cd .repo/manifests && git rev-parse --short HEAD)

# record changes since last build, if available
if wget -q ${BASE_URL}${PUB_DEST/\/${BUILD_NUMBER}\//\/latest\/}/pinned-manifest.xml -O pinned-manifest-latest.xml; then
    # https://github.com/96boards/oe-rpb-manifest/commit/0be354483a124903982103dc937f9e5c1a094a3a
    if grep -q ".*linkfile.*\.\./\.\./\.repo/manifests/setup-environment" pinned-manifest-latest.xml ; then
	echo "detected old style symlink with relative path, skipping diff report"
    else
	repo diffmanifests ${PWD}/pinned-manifest-latest.xml ${PWD}/pinned-manifest.xml > manifest-changes.txt
    fi
else
    echo "latest build published does not have pinned-manifest.xml, skipping diff report"
fi

# the setup-environment will create auto.conf and site.conf
# make sure we get rid of old config.
# let's remove the previous TMPDIR as well.
# we want to preserve build/buildhistory though.
rm -rf build/conf build/tmp-*glibc/

# Accept EULA if/when needed
export EULA_dragonboard410c=1
export EULA_stih410b2260=1
source setup-environment build

# Accept freescale EULA
cat << EOF >> conf/local.conf
ACCEPT_FSL_EULA = "1"
EOF

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

# FIXME LHG Specific: use a custom git fetcher command to workaround lhg-review.linaro.org broken SSHFP
cat << EOF >> conf/local.conf
FETCHCMD_git = "GIT_SSH_COMMAND="${GIT_SSH_COMMAND}" git -c core.fsyncobjectfiles=0"
EOF

# FIXME LHG Specific: don't override IMAGES
#[ "${DISTRO}" = "rpb" ] && IMAGES+=" rpb-desktop-image rpb-desktop-image-test"
#[ "${DISTRO}" = "rpb-wayland" ] && IMAGES+=" rpb-weston-image rpb-weston-image-test"
#[ "${MACHINE}" = "am57xx-evm" ] && IMAGES="rpb-console-image"

time bitbake ${IMAGES}

DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE="| cut -d'=' -f2 | tr -d '"')

# Prepare files to publish
rm -f ${DEPLOY_DIR_IMAGE}/*.txt
find ${DEPLOY_DIR_IMAGE} -type l -delete
mv /srv/oe/{source,pinned}-manifest.xml ${DEPLOY_DIR_IMAGE}
cat ${DEPLOY_DIR_IMAGE}/pinned-manifest.xml

# FIXME: Sparse images here, until it gets done by OE
case "${MACHINE}" in
  juno|stih410-b2260|orangepi-i96|imx8mqevk)
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
BOOT_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "boot-*-${MACHINE}-*-${BUILD_NUMBER}*.img" | xargs -r basename)
ROOTFS_EXT4_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-test-${MACHINE}-*-${BUILD_NUMBER}.rootfs.ext4.gz" | xargs -r basename)
ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-test-${MACHINE}-*-${BUILD_NUMBER}.rootfs.tar.xz" | xargs -r basename)
ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-test-${MACHINE}-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
ROOTFS_DESKTOP_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-desktop-image-test-${MACHINE}-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
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
ROOTFS_DESKTOP_SPARSE_BUILD_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_DESKTOP_IMG}
SYSTEM_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_EXT4_IMG}
KERNEL_URL=${BASE_URL}${PUB_DEST}/${KERNEL_IMG}
DTB_URL=${BASE_URL}${PUB_DEST}/${DTB_IMG}
NFSROOTFS_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_TARXZ_IMG}
EOF
