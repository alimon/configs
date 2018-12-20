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
pkg_list="virtualenv python-pip android-tools-fsutils chrpath cpio diffstat gawk libmagickwand-dev libmath-prime-util-perl libsdl1.2-dev libssl-dev python-requests texinfo vim-tiny whiptail libelf-dev pxz"
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
export MANIFEST_URL=${MANIFEST_URL:-https://github.com/96boards/oe-rpb-manifest.git}
if [ ! -e ".repo/manifest.xml" ]; then
   repo init -u ${MANIFEST_URL} -b ${MANIFEST_BRANCH}

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
BASE_URL=http://snapshots.linaro.org
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
source setup-environment build

########## vvv DISTRO DEPENDANT vvv ##########
if [ "${DISTRO}" = "rpb" ]; then

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

# Set the kernel to use
distro_conf=$(find ../layers/meta-rpb/conf/distro -name rpb.inc)
cat << EOF >> ${distro_conf}
PREFERRED_PROVIDER_virtual/kernel = "${KERNEL_RECIPE}"
EOF

case "${KERNEL_RECIPE}" in
  linux-hikey-aosp|linux-generic-android-common-o*|linux-generic-lsk*|linux-generic-stable*)
    cat << EOF >> ${distro_conf}
PREFERRED_VERSION_${KERNEL_RECIPE} = "${KERNEL_VERSION}+git%"
EOF
    ;;
esac

# Set the image types to use
cat << EOF >> ${distro_conf}
IMAGE_FSTYPES_remove = "ext4 iso wic"
EOF

# Set GCC to 7.x
cat << EOF >> ${distro_conf}
GCCVERSION = "7.%"
EOF

case "${KERNEL_RECIPE}" in
  linux-*-aosp|linux-*-android-*)
    cat << EOF >> ${distro_conf}
CONSOLE = "ttyFIQ0"
EOF
    ;;
esac

# Include additional recipes in the image
[ "${MACHINE}" = "am57xx-evm" -o "${MACHINE}" = "beaglebone" ] || extra_pkgs="numactl"
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
SERIAL_CONSOLES_remove_intel-core2-32 = "115200;ttyPCH0"
SERIAL_CONSOLES_remove_intel-corei7-64 = "115200;ttyPCH0"
SERIAL_CONSOLES_append_dragonboard-410c = " 115200;ttyMSM1"
SERIAL_CONSOLES_append_hikey = " 115200;ttyAMA2"
EOF

# Enable lkft-metadata class
cat << EOF >> conf/local.conf
INHERIT += "lkft-metadata"
LKFTMETADATA_COMMIT = "1"
EOF

# Update kernel recipe SRCREV
echo "SRCREV_kernel_${MACHINE} = \"${SRCREV_kernel}\"" >> conf/local.conf

fi
########## ^^^ DISTRO DEPENDANT ^^^ ##########

# Remove systemd firstboot and machine-id file
# Backport serialization change from v234 to avoid systemd tty race condition
# Only on Morty
if [ "${MANIFEST_BRANCH}" = "morty" ]; then
  mkdir -p ../layers/meta-96boards/recipes-core/systemd/systemd
  wget -q http://people.linaro.org/~fathi.boudra/backport-v234-e266c06-v230.patch \
    -O ../layers/meta-96boards/recipes-core/systemd/systemd/backport-v234-e266c06-v230.patch

  cat << EOF >> ../layers/meta-96boards/recipes-core/systemd/systemd/e2fsck.conf
[options]
# This will prevent e2fsck from stopping boot just because the clock is wrong
broken_system_clock = 1
EOF

  cat << EOF >> ../layers/meta-96boards/recipes-core/systemd/systemd_%.bbappend
FILESEXTRAPATHS_prepend := "\${THISDIR}/\${PN}:"

SRC_URI += "\\
    file://backport-v234-e266c06-v230.patch \\
    file://e2fsck.conf \\
"

PACKAGECONFIG_remove = "firstboot"

do_install_append() {
    # Install /etc/e2fsck.conf to avoid boot stuck by wrong clock time
    install -m 644 -p -D \${WORKDIR}/e2fsck.conf \${D}\${sysconfdir}/e2fsck.conf

    rm -f \${D}\${sysconfdir}/machine-id
}

FILES_\${PN} += "\${sysconfdir}/e2fsck.conf "
EOF
elif [ "${MANIFEST_BRANCH}" = "rocko" ]; then
  sed -i "s|bits/wordsize.h||" ../layers/openembedded-core/meta/recipes-core/glibc/glibc-package.inc
fi

# The kernel (as of next-20181130) requires fold from the host
echo "HOSTTOOLS += \"fold\"" >> conf/local.conf

# add useful debug info
cat conf/{site,auto}.conf
cat ${distro_conf}

# Temporary sstate cleanup to get lkft metadata generated
[ "${DISTRO}" = "rpb" ] && bitbake -c cleansstate kselftests-mainline kselftests-next ltp libhugetlbfs

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
      ${DEPLOY_DIR_IMAGE}/*.rootfs.wic* \
      ${DEPLOY_DIR_IMAGE}/*.iso \
      ${DEPLOY_DIR_IMAGE}/*.stimg

# FIXME: Sparse and converted images here, until it gets done by OE
case "${MACHINE}" in
  juno)
    ;;
  intel-core2-32|intel-corei7-64)
    for rootfs in ${DEPLOY_DIR_IMAGE}/*.hddimg; do
      pxz ${rootfs}
    done
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

h4. LKFT - OpenEmbedded

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Manifest URL: "${MANIFEST_URL}":${MANIFEST_URL}
* Manifest branch: ${MANIFEST_BRANCH}
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

GCCVERSION=$(bitbake -e | grep "^GCCVERSION="| cut -d'=' -f2 | tr -d '"')
TARGET_SYS=$(bitbake -e | grep "^TARGET_SYS="| cut -d'=' -f2 | tr -d '"')
TUNE_FEATURES=$(bitbake -e | grep "^TUNE_FEATURES="| cut -d'=' -f2 | tr -d '"')
STAGING_KERNEL_DIR=$(bitbake -e | grep "^STAGING_KERNEL_DIR="| cut -d'=' -f2 | tr -d '"')

if [ "${DISTRO}" = "rpb" ]; then
  # lkft-metadata class generates metadata file, which can be sourced
  for recipe in kselftests-mainline kselftests-next ltp libhugetlbfs; do
    source lkftmetadata/packages/*/${recipe}/metadata
  done
else
  # Generate LKFT metadata
  mkdir ${WORKSPACE}/lkftmetadata/
  for recipe in kselftests-mainline kselftests-next ltp libhugetlbfs ${KERNEL_RECIPE}; do
    tmpfile=$(mktemp)
    pkg=$(echo $recipe | tr '[a-z]-' '[A-Z]_')
    bitbake -e ${recipe} | grep -e ^PV= -e ^SRC_URI= -e ^SRCREV= > ${tmpfile}
    source ${tmpfile}
    for suri in $SRC_URI; do if [[ ! $suri =~ file:// ]]; then uri=$(echo $suri | cut -d\; -f1); export ${pkg}_URL=$uri; break; fi; done
    export ${pkg}_VERSION=${PV}
    export ${pkg}_REVISION=${SRCREV}
    unset -v PV SRC_URI SRCREV
    rm ${tmpfile}
    for v in URL VERSION REVISION; do
      myvar="${pkg}_${v}"
      echo "${myvar}=${!myvar}" >> ${WORKSPACE}/lkftmetadata/${recipe}
    done
  done
fi

BOOT_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "boot-*-${MACHINE}-*-${BUILD_NUMBER}*.img" | sort | xargs -r basename)
KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "*Image-*-${MACHINE}-*-${BUILD_NUMBER}.bin" | xargs -r basename)
ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-lkft-${MACHINE}-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
ROOTFS_EXT4=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-lkft-${MACHINE}-*-${BUILD_NUMBER}.rootfs.ext4.gz" | xargs -r basename)
ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-lkft-${MACHINE}-*-${BUILD_NUMBER}.rootfs.tar.xz" | xargs -r basename)
HDD_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-lkft-${MACHINE}-*-${BUILD_NUMBER}.hddimg.xz" | xargs -r basename)
case "${MACHINE}" in
  am57xx-evm)
    # QEMU arm 32bit needs the zImage file, not the uImage file.
    # KERNEL_IMG is not used for the real hardware itself.
    KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "zImage-*-${MACHINE}-*-${BUILD_NUMBER}.bin" | xargs -r basename)
    ;;
  juno)
    DTB_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "*Image-*-${MACHINE}-r2-*-${BUILD_NUMBER}.dtb" | xargs -r basename)
    ;;
esac

cat > ${DEPLOY_DIR_IMAGE}/build_config.json <<EOF
{
  "kernel_repo" : "${KERNEL_REPO}",
  "kernel_commit_id" : "${SRCREV_kernel}",
  "make_kernelversion" : "${MAKE_KERNELVERSION}",
  "kernel_branch" : "${KERNEL_BRANCH}",
  "kernel_describe" : "${KERNEL_DESCRIBE}",
  "kselftest_mainline_url" : "${KSELFTESTS_MAINLINE_URL}",
  "kselftest_mainline_version" : "${KSELFTESTS_MAINLINE_VERSION}",
  "kselftest_next_url" : "${KSELFTESTS_NEXT_URL}",
  "kselftest_next_version" : "${KSELFTESTS_NEXT_VERSION}",
  "ltp_url" : "${LTP_URL}",
  "ltp_version" : "${LTP_VERSION}",
  "ltp_revision" : "${LTP_REVISION}",
  "libhugetlbfs_url" : "${LIBHUGETLBFS_URL}",
  "libhugetlbfs_version" : "${LIBHUGETLBFS_VERSION}",
  "libhugetlbfs_revision" : "${LIBHUGETLBFS_REVISION}",
  "build_arch" : "${TUNE_FEATURES}",
  "compiler" : "${TARGET_SYS} ${GCCVERSION}",
  "build_location" : "${BASE_URL}/${PUB_DEST}"
}
EOF

cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
BASE_URL=${BASE_URL}
BOOT_URL=${BASE_URL}/${PUB_DEST}/${BOOT_IMG}
SYSTEM_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_IMG}
KERNEL_URL=${BASE_URL}/${PUB_DEST}/${KERNEL_IMG}
DTB_URL=${BASE_URL}/${PUB_DEST}/${DTB_IMG}
RECOVERY_IMAGE_URL=${BASE_URL}/${PUB_DEST}/juno-oe-uboot.zip
NFSROOTFS_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_TARXZ_IMG}
EXT4_IMAGE_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_EXT4}
HDD_URL=${BASE_URL}/${PUB_DEST}/${HDD_IMG}
KERNEL_COMMIT=${SRCREV_kernel}
KERNEL_CONFIG_URL=${BASE_URL}/${PUB_DEST}/config
KERNEL_DEFCONFIG_URL=${BASE_URL}/${PUB_DEST}/defconfig
KSELFTESTS_MAINLINE_URL=${KSELFTESTS_MAINLINE_URL}
KSELFTESTS_MAINLINE_VERSION=${KSELFTESTS_MAINLINE_VERSION}
KSELFTESTS_NEXT_URL=${KSELFTESTS_NEXT_URL}
KSELFTESTS_NEXT_VERSION=${KSELFTESTS_NEXT_VERSION}
LTP_URL=${LTP_URL}
LTP_VERSION=${LTP_VERSION}
LTP_REVISION=${LTP_REVISION}
LIBHUGETLBFS_URL=${LIBHUGETLBFS_URL}
LIBHUGETLBFS_VERSION=${LIBHUGETLBFS_VERSION}
LIBHUGETLBFS_REVISION=${LIBHUGETLBFS_REVISION}
MAKE_KERNELVERSION=${MAKE_KERNELVERSION}
TOOLCHAIN="${TARGET_SYS} ${GCCVERSION}"
EOF
