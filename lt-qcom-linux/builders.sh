#!/bin/bash

if [ ! -d "${WORKSPACE}" ]; then
    set -x
    WORKSPACE=$(pwd)
    BUILD_NUMBER=0
else
    set -ex
fi

cd ${WORKSPACE}/linux

if [ -z "${ARCH}" ]; then
    export ARCH=arm64
    export KERNEL_CONFIGS_arm64="defconfig distro.config"
fi
if [ -z "${KERNEL_VERSION}" ]; then
    KERNEL_VERSION=$(make kernelversion)
fi
if [ -z "${KERNEL_DESCRIBE}" ]; then
    KERNEL_DESCRIBE=$(git describe --always)
fi
if [ -z "${KDEB_CHANGELOG_DIST}" ]; then
    KDEB_CHANGELOG_DIST="unstable"
fi
if [ -z "${KERNEL_BUILD_TARGET}" ]; then
    KERNEL_BUILD_TARGET="all"
fi

echo "Starting ${JOB_NAME} with the following parameters:"
echo "KERNEL_DESCRIBE: ${KERNEL_DESCRIBE}"
echo "KERNEL_VERSION: ${KERNEL_VERSION}"
echo "KERNEL_BRANCH: ${KERNEL_BRANCH}"
echo "GIT_COMMIT: ${GIT_COMMIT}"
echo "GIT_BRANCH: ${GIT_BRANCH}"

# tcbindir from install-gcc-toolchain.sh
export CROSS_COMPILE="ccache $(basename $(ls -1 ${tcbindir}/*-gcc) gcc)"
export PATH=${tcbindir}:$PATH

# SRCVERSION is the main kernel version, e.g. <version>.<patchlevel>.0.
# PKGVERSION is similar to make kernelrelease, but reimplemented, since it requires setting up the build (and all tags).
# e.g. SRCVERSION -> 4.9.0, PKGVERSION -> 4.9.47-530-g244b81e58a54, which leads to
#      linux-4.9.0-qcomlt (4.9.47-530-g244b81e58a54-99)
SRCVERSION=$(echo ${KERNEL_VERSION} | sed 's/\(.*\)\..*/\1.0/')
PKGVERSION=$(echo ${KERNEL_VERSION} | sed -e 's/\.0-rc/\.0~rc/')$(echo ${KERNEL_DESCRIBE} | awk -F- '{printf("-%05d-%s", $(NF-1),$(NF))}')

KERNEL_CONFIGS=KERNEL_CONFIGS_$ARCH
make distclean
make ${!KERNEL_CONFIGS}
if [ "${UPDATE_DEFCONFIG}" ]; then
	make savedefconfig
	cp defconfig arch/${ARCH}/configs
fi

make KERNELRELEASE=${SRCVERSION}-qcomlt-${ARCH} \
     KDEB_PKGVERSION=${PKGVERSION}-${BUILD_NUMBER} \
     KDEB_CHANGELOG_DIST=${KDEB_CHANGELOG_DIST} \
     DEBEMAIL="dragonboard@lists.96boards.org" \
     DEBFULLNAME="Linaro Qualcomm Landing Team" \
     -j$(nproc) ${KERNEL_BUILD_TARGET}
if [ "${INSTALL_MOD}" ]; then
     make KERNELRELEASE=${SRCVERSION}-qcomlt-${ARCH} -j$(nproc) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=./INSTALL_MOD_PATH modules_install
fi
cd ..

cat > params <<EOF
source=${JOB_URL}/ws/$(echo *.dsc)
repo=${TARGET_REPO}
EOF
