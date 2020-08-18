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
pkg_list="build-essential python-pip android-tools-fsutils chrpath cpio diffstat gawk libmagickwand-dev libmath-prime-util-perl libsdl1.2-dev libssl-dev python-crypto python-requests texinfo vim-tiny whiptail"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

# Install jinja2-cli and ruamel.yaml
pip install --user --force-reinstall jinja2-cli ruamel.yaml

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

if [ "${ghprbPullId}" ]; then
    echo "Applying Github pull-request #${ghprbPullId} from ${ghprbGhRepository}"
    sed -i -e "s|name=\"${ghprbGhRepository}\"|name=\"${ghprbGhRepository}\" revision=\"refs/pull/${ghprbPullId}/head\"|" .repo/manifest.xml
fi

repo sync
cp .repo/manifest.xml source-manifest.xml
repo manifest -r -o pinned-manifest.xml
MANIFEST_COMMIT=$(cd .repo/manifests && git rev-parse --short HEAD)
echo "MANIFEST_COMMIT=${MANIFEST_COMMIT}" > ${WORKSPACE}/submit_for_testing_parameters

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

# Override cmdline
cat << EOF >> conf/local.conf
CMDLINE_remove = "quiet"
EOF

# Accept freescale EULA
cat << EOF >> conf/local.conf
ACCEPT_FSL_EULA = "1"
EOF

# add useful debug info
cat conf/{site,auto}.conf

# if ${IMAGES} is not set or empty, set it to default
if [ "x${IMAGES}" = "x" ]; then
    [ "${DISTRO}" = "rpb" ] && IMAGES="rpb-desktop-image"
    [ "${DISTRO}" = "rpb-wayland" ] && IMAGES="rpb-weston-image"
fi

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
  juno|stih410-b2260)
    ;;
  *)
    for rootfs in ${DEPLOY_DIR_IMAGE}/*.rootfs.ext4.gz; do
      if [ -e ${rootfs} ]; then
        gunzip -k ${rootfs}
        sudo ext2simg -v ${rootfs%.gz} ${rootfs%.ext4.gz}.img
        rm -f ${rootfs%.gz}
        gzip -9 ${rootfs%.ext4.gz}.img
      fi
    done
    ;;
esac

# Create MD5SUMS file
find ${DEPLOY_DIR_IMAGE} -type f | xargs md5sum > MD5SUMS.txt
sed -i "s|${DEPLOY_DIR_IMAGE}/||" MD5SUMS.txt
mv MD5SUMS.txt ${DEPLOY_DIR_IMAGE}

# Build information
cat > ${DEPLOY_DIR_IMAGE}/HEADER.textile << EOF

h4. Linaro Home Group Build - OpenEmbedded

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

# The archive publisher can't handle files located outside
# ${WORKSPACE} - create the link before archiving.
rm -f ${WORKSPACE}/out
ln -s ${DEPLOY_DIR_IMAGE} ${WORKSPACE}/out

# Need different files for each machine
BOOT_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "boot-*-${MACHINE}-*-${BUILD_NUMBER}*.img" | xargs -r basename)
ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-westonchromium-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
ROOTFS_EXT4_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-westonchromium-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.ext4.gz" | xargs -r basename)
ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-westonchromium-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.tar.xz" | xargs -r basename)
KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "uImage-*-${MACHINE}-*-${BUILD_NUMBER}.bin" | xargs -r basename)
PTABLE_IMG=$(find ${DEPLOY_DIR_IMAGE}/bootloader -type f -name "ptable-linux-8g.img" | xargs -r basename)
FIP_IMG=$(find ${DEPLOY_DIR_IMAGE}/bootloader -type f -name "fip.bin" | xargs -r basename)
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
SYSTEM_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_IMG}
KERNEL_URL=${BASE_URL}${PUB_DEST}/${KERNEL_IMG}
DTB_URL=${BASE_URL}${PUB_DEST}/${DTB_IMG}
NFSROOTFS_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_TARXZ_IMG}
PTABLE_URL=http://images.validation.linaro.org/builds.96boards.org/snapshots/reference-platform/components/uefi-staging/49/hikey/release/ptable-linux-8g.img
FIP_URL=${BASE_URL}${PUB_DEST}/bootloader/${FIP_IMG}
EOF
