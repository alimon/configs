#!/bin/bash

set -ex

function build_integration_kernel()
{
	export ARCH=$1
	export KERNEL_CONFIGS=$2

	toolchain_url_arm=http://releases.linaro.org/components/toolchain/binaries/6.3-2017.02/arm-linux-gnueabihf/gcc-linaro-6.3.1-2017.02-x86_64_arm-linux-gnueabihf.tar.xz
	toolchain_url_arm64=http://releases.linaro.org/components/toolchain/binaries/6.3-2017.02/aarch64-linux-gnu/gcc-linaro-6.3.1-2017.02-x86_64_aarch64-linux-gnu.tar.xz
	toolchain_url=toolchain_url_$ARCH
	toolchain_url=${!toolchain_url}

	tcdir=${HOME}/srv/toolchain
	tcbindir="${tcdir}/$(basename $toolchain_url .tar.xz)/bin"

	export CROSS_COMPILE="ccache $(basename $(ls -1 ${tcbindir}/*-gcc) gcc)"
	export PATH=${tcbindir}:$PATH

	make distclean
	make ${KERNEL_CONFIGS}
	make savedefconfig
	cp defconfig arch/${ARCH}/configs

	make KERNELRELEASE=qcomlt-integration-${ARCH} -j$(nproc) Image
}

if [ ${AUTOMERGE_EXIT_CODE} -ne 0 ]; then
	exit ${AUTOMERGE_EXIT_CODE}
fi

cd ${INTEGRATION_REPO_PATH}
build_integration_kernel "arm" "multi_v7_defconfig"
build_integration_kernel "arm64" "defconfig"

if [ ! -z ${KERNEL_CI_REPO_URL} ]; then
	git push -f ${KERNEL_CI_REPO_URL} ${INTEGRATION_BRANCH}:${KERNEL_CI_BRANCH}
fi
