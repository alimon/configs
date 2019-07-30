#!/bin/bash

set -e

# workaround EDK2 is confused by the long path used during the build
# and truncate files name expected by VfrCompile
sudo mkdir -p /srv/build
sudo chown buildslave:buildslave /srv/build
cd /srv/build

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

pkg_list="libguestfs-tools linux-image-amd64"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

sudo locale-gen en_US.UTF-8 && sudo update-locale LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

set -ex

# Store the home repository
if [ -z "${WORKSPACE}" ]; then
  # Local build
  export WORKSPACE=${PWD}
fi

git clone --depth 1 http://git.linaro.org/ci/job/configs.git
cd configs/fedora-iot/
pwd
ls
sudo ./build_fiot.sh

DEPLOY_DIR_IMAGE=`pwd`/deploy

# Note: the main job script allows to override the default value for
#       BASE_URL and PUB_DEST, typically used for OE RPB builds
cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
EOF

# Build information
cat > ${DEPLOY_DIR_IMAGE}/HEADER.textile << EOF

h4. LEDGE - Fedora IoT 

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Manifest URL: "${MANIFEST_URL}":${MANIFEST_URL}
* Manifest branch: ${MANIFEST_BRANCH}
EOF

ls -lh  ${DEPLOY_DIR_IMAGE}
BOOT_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "boot-*${MACHINE}-*${BUILD_NUMBER}*.img" | sort | xargs -r basename)
KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "*vmlinu**" | xargs -r basename)
ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "ledge-*${MACHINE}-*${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
ROOTFS_EXT4=$(find ${DEPLOY_DIR_IMAGE} -type f -name "ledge-*${MACHINE}-*${BUILD_NUMBER}.rootfs.ext4.gz" | xargs -r basename)
ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "fiot-rootfs*" | xargs -r basename)
HDD_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "ledge-*${MACHINE}-*${BUILD_NUMBER}.hddimg.xz" | xargs -r basename)
INITRD_URL=$(find ${DEPLOY_DIR_IMAGE} -type f -name "initram*" | xargs -r basename)


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
MANIFEST_COMMIT=${MANIFEST_COMMIT}
BASE_URL=${BASE_URL}
BOOT_URL=${BASE_URL}/${PUB_DEST}/${BOOT_IMG}
ROOTFS_SPARSE_BUILD_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_IMG}
SYSTEM_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_IMG}
KERNEL_URL=${BASE_URL}/${PUB_DEST}/${KERNEL_IMG}
DTB_URL=${BASE_URL}/${PUB_DEST}/${DTB_IMG}
RECOVERY_IMAGE_URL=${BASE_URL}/${PUB_DEST}/none.zip
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
KERNEL_ARGS="${KERNEL_ARGS}"
INITRD_URL="${INITRD_URL}"
EOF

cat ${WORKSPACE}/post_build_lava_parameters
