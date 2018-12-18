#!/bin/bash

set -ex

DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE=" | cut -d'=' -f2 | tr -d '"')

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
      pigz -d -k ${rootfs}
      sudo ext2simg -v ${rootfs%.gz} ${rootfs%.ext4.gz}.img
      rm -f ${rootfs%.gz}
      pigz -9 ${rootfs%.ext4.gz}.img
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

# lkft-metadata class generates metadata file, which can be sourced
for recipe in kselftests-mainline kselftests-next ltp libhugetlbfs; do
  source lkftmetadata/packages/*/${recipe}/metadata
done

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

