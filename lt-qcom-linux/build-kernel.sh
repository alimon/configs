#!/bin/bash

set -ex

toolchain_url_arm=http://releases.linaro.org/components/toolchain/binaries/6.3-2017.02/arm-linux-gnueabihf/gcc-linaro-6.3.1-2017.02-x86_64_arm-linux-gnueabihf.tar.xz
toolchain_url_arm64=http://releases.linaro.org/components/toolchain/binaries/6.3-2017.02/aarch64-linux-gnu/gcc-linaro-6.3.1-2017.02-x86_64_aarch64-linux-gnu.tar.xz
toolchain_url=toolchain_url_$ARCH
toolchain_url=${!toolchain_url}

tcdir=${HOME}/srv/toolchain
tcbindir="${tcdir}/$(basename $toolchain_url .tar.xz)/bin"

export CROSS_COMPILE="ccache $(basename $(ls -1 ${tcbindir}/*-gcc) gcc)"
export PATH=${tcbindir}:$PATH

pushd ${WORKSPACE}/linux

# bring in stable and mainline tags
#git fetch --tags https://kernel.googlesource.com/pub/scm/linux/kernel/git/torvalds/linux.git
#git fetch --tags https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux-stable.git

KERNEL_DESCRIBE=$(git describe --always)

# Build information
mkdir -p ${WORKSPACE}/out ${WORKSPACE}/out/dtbs
cat > ${WORKSPACE}/out/HEADER.textile << EOF

h4. QC LT kernel build

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* KERNEL_REPO_URL: $KERNEL_REPO_URL
* KERNEL_BRANCH: $KERNEL_BRANCH
* ARCH: $ARCH
* KERNEL_DESCRIBE: $KERNEL_DESCRIBE
* KERNEL_CONFIGS: $KERNEL_CONFIGS
EOF

# Config
if [ -f ./chromeos/scripts/prepareconfig ] && [ -f chromeos/config/$ARCH/"${KERNEL_CONFIGS}.flavour.config" ]; then
    mkdir build
    ./chromeos/scripts/prepareconfig ${KERNEL_CONFIGS} build/.config
    make O=build olddefconfig
else
    make O=build ${KERNEL_CONFIGS}
fi

# Build
make -j$(nproc) O=build
make -j$(nproc) O=build INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=./INSTALL_MOD_PATH modules_install

# Install files to publish
(cd build/INSTALL_MOD_PATH && find . | cpio -ov -H newc | gzip > ${WORKSPACE}/out/kernel-modules.cpio.gz)
(cd build/INSTALL_MOD_PATH && tar cJvf ${WORKSPACE}/out/kernel-modules.tar.xz .)
cp build/.config ${WORKSPACE}/out/kernel.config
cp build/{System.map,vmlinux} ${WORKSPACE}/out/
cp build/arch/$ARCH/boot/Image* ${WORKSPACE}/out
(cd build/arch/$ARCH/boot/dts && cp -a --parents $(find . -name *.dtb) ${WORKSPACE}/out/dtbs)

popd

# publish builds by branch
BRANCH_NAME_URL=$(echo ${KERNEL_BRANCH} | sed -e 's/[^A-Za-z0-9._-]/_/g')
echo "PUB_DEST=member-builds/qcomlt/kernel/${BRANCH_NAME_URL}/${BUILD_NUMBER}" > pub_dest_parameters
