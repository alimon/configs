#!/bin/bash

set -ex

cd linux/
KERNEL_DESCRIBE=`git describe --match 'v4*'| sed -e 's,^v,,'`
KERNEL_VERSION=`echo ${KERNEL_DESCRIBE}|sed 's,-.*,,' `

echo "Starting ${JOB_NAME} with the following parameters:"
echo "KERNEL_DESCRIBE: ${KERNEL_DESCRIBE}"
echo "KERNEL_VERSION: ${KERNEL_VERSION}"
echo "KERNEL_BRANCH: ${KERNEL_BRANCH}"
echo "GIT_COMMIT: ${GIT_COMMIT}"
echo "GIT_BRANCH: ${GIT_BRANCH}"

sudo apt-get update -q
sudo apt-get install -q -y bc kmod cpio

SRCVERSION=$(echo ${KERNEL_VERSION} |sed 's,-rc,,')
PKGVERSION=$(echo ${KERNEL_DESCRIBE} |sed -e 's,-rc,~rc,')

make ${KERNEL_CONFIGS}
make savedefconfig
cp defconfig arch/${ARCH}/configs

make KERNELRELEASE=${SRCVERSION}-hikey \
     KDEB_PKGVERSION=${PKGVERSION}-${BUILD_NUMBER} \
     KDEB_CHANGELOG_DIST=${KDEB_CHANGELOG_DIST} \
     DEBEMAIL="packages@lists.96boards.org" \
     DEBFULLNAME="Linaro" \
     -j$(nproc) ${KERNEL_BUILD_TARGET}

cd ..

cat > params <<EOF
source=${JOB_URL}/ws/$(echo *.dsc)
repo=${TARGET_REPO}
EOF
