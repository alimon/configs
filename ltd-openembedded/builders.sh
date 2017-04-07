#!/bin/bash
#
# Based on the OE RPB build jobs, could later be merged as part of RPB
# For now this is just a development build.

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
   repo init -u https://github.com/linaro-technologies/oe-rpb-manifest.git -b ${MANIFEST_BRANCH}

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

# the setup-environment will create auto.conf and site.conf
# make sure we get rid of old config.
# let's remove the previous TMPDIR as well.
# we want to preserve build/buildhistory though.
rm -rf conf build/conf build/tmp-*glibc/

# Accept EULA if/when needed
export EULA_dragonboard410c=1
export EULA_stih410b2260=1
source setup-environment build

# EULA for FSL
cat << EOF >> conf/auto.conf
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

bitbake ${IMAGES}

DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE="| cut -d'=' -f2 | tr -d '"')

# Prepare files to publish
rm -f ${DEPLOY_DIR_IMAGE}/*.txt
rm -rf ${DEPLOY_DIR_IMAGE}/bootloader
find ${DEPLOY_DIR_IMAGE} -type l -delete
mv /srv/oe/{source,pinned}-manifest.xml ${DEPLOY_DIR_IMAGE}
cat ${DEPLOY_DIR_IMAGE}/pinned-manifest.xml

# FIXME: Sparse images here, until it gets done by OE
case "${MACHINE}" in
  cubox-i|stih410-b2260)
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
  mkdir -p ${DEPLOY_DIR_IMAGE}/bootloader
  (cd ${DEPLOY_DIR_IMAGE} && mv fip.bin hisi-idt.py l-loader.bin nvme.img ptable-linux-*.img bootloader/)
}

# Create MD5SUMS file
find ${DEPLOY_DIR_IMAGE} -type f | xargs md5sum > MD5SUMS.txt
sed -i "s|${DEPLOY_DIR_IMAGE}/||" MD5SUMS.txt
mv MD5SUMS.txt ${DEPLOY_DIR_IMAGE}

# Build information
cat > ${DEPLOY_DIR_IMAGE}/HEADER.textile << EOF

h4. Linaro Technologies - Gateway RPB (Development)

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Manifest URL: "https://github.com/linaro-technologies/oe-rpb-manifest.git":https://github.com/linaro-technologies/oe-rpb-manifest.git
* Manifest branch: ${MANIFEST_BRANCH}
* Manifest commit: "${MANIFEST_COMMIT}":https://github.com/linaro-technologies/oe-rpb-manifest/commit/${MANIFEST_COMMIT}
EOF

cat << EOF > ${WORKSPACE}/post_build_parameters
DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
EOF
