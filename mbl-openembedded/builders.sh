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
pkg_list="virtualenv python-pip android-tools-fsutils chrpath cpio diffstat gawk libmagickwand-dev libmath-prime-util-perl libsdl1.2-dev libssl-dev python-crypto python-requests texinfo vim-tiny whiptail libelf-dev"
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
  ssh-keyscan github.com >> ${HOME}/.ssh/known_hosts

  MANIFEST_FILE=default.xml
  case "${MANIFEST_BRANCH}" in
    linaro-*-pinned)
      MANIFEST_FILE=pinned-manifest.xml
      ;;
  esac

  repo init -u git@github.com:ARMmbed/mbl-manifest.git -b ${MANIFEST_BRANCH_PREFIX}${MANIFEST_BRANCH} -m ${MANIFEST_FILE}

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

# Set the image types to use
distro_conf=$(find ../layers/meta-rpb/conf/distro -name rpb.inc)
cat << EOF >> ${distro_conf}
IMAGE_FSTYPES_remove_imx7s-warp = "ext4"
IMAGE_FSTYPES_append_imx7s-warp = " ext4.gz"
IMAGE_FSTYPES_remove_raspberrypi3 = "tar.bz2"
IMAGE_FSTYPES_remove_raspberrypi3 = "ext3"
IMAGE_FSTYPES_append_raspberrypi3 = " ext3.gz"
EOF

# add useful debug info
cat conf/{site,auto}.conf

case "${MACHINE}" in
  imx7s-warp)
    # Temporary sstate cleanup to force warp7 firmware to be re-generated each time
    bitbake -c cleansstate u-boot-fslc imx7-efuse-util imx7-cst-native warp7-keys-native warp7-csf-native warp7-u-boot-scr
    ;;
esac

time bitbake ${IMAGES}

DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE="| cut -d'=' -f2 | tr -d '"')

# Prepare files to publish
rm -f ${DEPLOY_DIR_IMAGE}/*.txt
find ${DEPLOY_DIR_IMAGE} -type l -delete
mv /srv/oe/{source,pinned}-manifest.xml ${DEPLOY_DIR_IMAGE}
cat ${DEPLOY_DIR_IMAGE}/pinned-manifest.xml

# FIXME: IMAGE_FSTYPES_remove doesn't work
rm -f ${DEPLOY_DIR_IMAGE}/*.rootfs.ext?

# FIXME: Sparse images here, until it gets done by OE
case "${MACHINE}" in
  juno|stih410-b2260|imx7s-warp|raspberrypi3)
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

h4. MBL Build - OpenEmbedded

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Manifest URL: "https://github.com/ARMmbed/mbl-manifest.git":https://github.com/ARMmbed/mbl-manifest.git
* Manifest branch: ${MANIFEST_BRANCH_PREFIX}${MANIFEST_BRANCH}
* Manifest commit: "${MANIFEST_COMMIT}":https://github.com/ARMmbed/mbl-manifest/commit/${MANIFEST_COMMIT}
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

# Note: the main job script allows to override the default value for
#       BASE_URL and PUB_DEST, typically used for OE RPB builds
cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
MANIFEST_COMMIT=${MANIFEST_COMMIT}
EOF
