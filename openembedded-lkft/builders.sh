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
   repo init -u https://github.com/96boards/oe-rpb-manifest.git -b ${MANIFEST_BRANCH}

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

# Set the kernel to use for HiKey
cat << EOF >> conf/site.conf
PREFERRED_PROVIDER_virtual/kernel = "${KERNEL_RECIPE}"
EOF

[ "${KERNEL_RECIPE}" = "linux-hikey-aosp" ] && cat << EOF >> conf/site.conf
PREFERRED_VERSION_${KERNEL_RECIPE} = "${KERNEL_VERSION}+git%"
EOF

# Include additional recipes in the image
cat << EOF >> conf/local.conf
CORE_IMAGE_BASE_INSTALL_append = " kernel-selftests kselftests libhugetlbfs-tests ltp"
CORE_IMAGE_BASE_INSTALL_append = " acl attr numactl"
CORE_IMAGE_BASE_INSTALL_append = " python python-misc python-modules python-numpy python-pexpect python-pyyaml"
EOF

# Override cmdline
cat << EOF >> conf/local.conf
CMDLINE_remove = "quiet"
EOF

# Remove 96boards-tools to avoid resizing on first boot
cat << EOF >> conf/local.conf
RDEPENDS_packagegroup-rpb_remove = "96boards-tools"
EOF

# Remove systemd firstboot and machine-id file
mkdir -p ../layers/meta-96boards/recipes-core/systemd
cat << EOF >> ../layers/meta-96boards/recipes-core/systemd/systemd_%.bbappend
PACKAGECONFIG_remove = "firstboot"

do_install_append() {
    rm -f \${D}\${sysconfdir}/machine-id
}
EOF

# Update kernel recipe SRCREV
SRCREV_kernel=$(git ls-remote ${KERNEL_REPO} refs/heads/${KERNEL_BRANCH} | cut -f1)
kernel_recipe=$(find ../layers/meta-96boards -type f -name ${KERNEL_RECIPE}_${KERNEL_VERSION}.bb)
sed -i "s|^SRCREV_kernel = .*|SRCREV_kernel = \"${SRCREV_kernel}\"|" ${kernel_recipe}

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
# FIXME: am57xx-evm creates tar.xz rootfs image and
#        meta-ti u-boot doesn't enable fastboot support
case "${MACHINE}" in
  am57xx-evm|stih410-b2260)
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

h4. LKFT - OpenEmbedded

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Manifest URL: "https://github.com/96boards/oe-rpb-manifest.git":https://github.com/96boards/oe-rpb-manifest.git
* Manifest branch: ${MANIFEST_BRANCH}
* Manifest commit: "${MANIFEST_COMMIT}":https://github.com/96boards/oe-rpb-manifest/commit/${MANIFEST_COMMIT}
EOF

SRCREV_kernel=$(bitbake -e ${KERNEL_RECIPE} | grep "^SRCREV_kernel="| cut -d'=' -f2 | tr -d '"')
GCCVERSION=$(bitbake -e | grep "^GCCVERSION="| cut -d'=' -f2 | tr -d '"')
TARGET_SYS=$(bitbake -e | grep "^TARGET_SYS="| cut -d'=' -f2 | tr -d '"')
TUNE_FEATURES=$(bitbake -e | grep "^TUNE_FEATURES="| cut -d'=' -f2 | tr -d '"')
STAGING_KERNEL_DIR=$(bitbake -e | grep "^STAGING_KERNEL_DIR="| cut -d'=' -f2 | tr -d '"')
KERNEL_DESCRIBE=$(cd ${STAGING_KERNEL_DIR} && git describe --always)

cat > ${DEPLOY_DIR_IMAGE}/build_config.json <<EOF
{
  "kernel_repo" : "${KERNEL_REPO}",
  "kernel_commit_id" : "${SRCREV_kernel}",
  "kernel_branch" : "${KERNEL_BRANCH}",
  "kernel_describe" : "${KERNEL_DESCRIBE}",
  "build_arch" : "${TUNE_FEATURES}",
  "compiler" : "${TARGET_SYS} ${GCCVERSION}"
}
EOF

# FIXME handle properly the publishing URL
case "${KERNEL_RECIPE}" in
  linux-hikey-stable)
    PUB_DEST="linux-stable-4.9"
    ;;
  linux-hikey-next)
    PUB_DEST="linux-next"
    ;;
  linux-hikey-lt)
    PUB_DEST="linux-lt-4.4"
    ;;
  *)
    PUB_DEST="${KERNEL_VERSION}"
    ;;
esac

SNAPSHOTS_URL=https://snapshots.linaro.org
BASE_URL=openembedded/lkft/${MANIFEST_BRANCH}/${MACHINE}/${DISTRO}/${PUB_DEST}/${BUILD_NUMBER}
BOOT_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "boot-*-${MACHINE}-*-${BUILD_NUMBER}.uefi.img" | xargs -r basename)
ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)

cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
BASE_URL=${BASE_URL}
BOOT_URL=${SNAPSHOTS_URL}/${BASE_URL}/${BOOT_IMG}
SYSTEM_URL=${SNAPSHOTS_URL}/${BASE_URL}/${ROOTFS_IMG}
KERNEL_COMMIT=${SRCREV_kernel}
KERNEL_DESCRIBE="${KERNEL_DESCRIBE}"
EOF
