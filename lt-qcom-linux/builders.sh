#!/bin/bash

set -ex

echo "Starting ${JOB_NAME} with the following parameters:"
echo "KERNEL_DESCRIBE: ${KERNEL_DESCRIBE}"
echo "KERNEL_VERSION: ${KERNEL_VERSION}"
echo "KERNEL_BRANCH: ${KERNEL_BRANCH}"
echo "GIT_COMMIT: ${GIT_COMMIT}"
echo "GIT_BRANCH: ${GIT_BRANCH}"

toolchain_url_arm=http://releases.linaro.org/components/toolchain/binaries/6.3-2017.02/arm-linux-gnueabihf/gcc-linaro-6.3.1-2017.02-x86_64_arm-linux-gnueabihf.tar.xz
toolchain_url_arm64=http://releases.linaro.org/components/toolchain/binaries/6.3-2017.02/aarch64-linux-gnu/gcc-linaro-6.3.1-2017.02-x86_64_aarch64-linux-gnu.tar.xz
toolchain_url=toolchain_url_$ARCH
toolchain_url=${!toolchain_url}

tcdir=${HOME}/srv/toolchain
tcbindir="${tcdir}/$(basename $toolchain_url .tar.xz)/bin"

export CROSS_COMPILE="ccache $(basename $(ls -1 ${tcbindir}/*-gcc) gcc)"
export PATH=${tcbindir}:$PATH

# SRCVERSION is the main kernel version, e.g. <version>.<patchlevel>.0.
# PKGVERSION is similar to make kernelrelease, but reimplemented, since it requires setting up the build (and all tags).
# e.g. SRCVERSION -> 4.9.0, PKGVERSION -> 4.9.47-530-g244b81e58a54, which leads to
#      linux-4.9.0-qcomlt (4.9.47-530-g244b81e58a54-99)
SRCVERSION=$(echo ${KERNEL_VERSION} | sed 's/\(.*\)\..*/\1.0/')
PKGVERSION=$(echo ${KERNEL_VERSION} | sed -e 's/\.0-rc/\.0~rc/')$(echo ${KERNEL_DESCRIBE} | awk -F- '{printf("-%05d-%s", $(NF-1),$(NF))}')

cd ${WORKSPACE}/linux

KERNEL_CONFIGS=KERNEL_CONFIGS_$ARCH
make ${!KERNEL_CONFIGS}
make savedefconfig
cp defconfig arch/${ARCH}/configs

make KERNELRELEASE=${SRCVERSION}-qcomlt-${ARCH} \
     KDEB_PKGVERSION=${PKGVERSION}-${BUILD_NUMBER} \
     KDEB_CHANGELOG_DIST=${KDEB_CHANGELOG_DIST} \
     DEBEMAIL="dragonboard@lists.96boards.org" \
     DEBFULLNAME="Linaro Qualcomm Landing Team" \
     -j$(nproc) deb-pkg

cd ..

cat > params <<EOF
source=${JOB_URL}/ws/$(echo *.dsc)
repo=${TARGET_REPO}
EOF
