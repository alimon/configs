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

	# build QCOM DTBS with warnings
	make W=1 arch/arm64/boot/dts/qcom/  2>&1 | tee -a qcom-dtbs.log
	make -j$(nproc)
}

if [ ${AUTOMERGE_EXIT_CODE} -ne 0 ]; then
	echo "ERROR: Automerge failed, returned ${AUTOMERGE_EXIT_CODE}"
	exit ${AUTOMERGE_EXIT_CODE}
fi

if [ ! -z "${AUTOMERGE_BRANCH_FAILED}" ]; then
	echo "ERROR: Automerge failed,"
	echo "${AUTOMERGE_BRANCH_FAILED}"
	exit 1
fi

pushd ${INTEGRATION_REPO_PATH}

GIT_STATUS=$(git status -s)
if [ ! -z "${GIT_STATUS}" ]; then
	echo "ERROR: Automerge repository isn't clean,"
	echo "${GIT_STATUS}"
	exit 1
fi

build_integration_kernel "arm" "multi_v7_defconfig"
build_integration_kernel "arm64" "defconfig"

# record QCOM DTBS warnings, for all builds
DTBS_WARNINGS=$(sed -n "s/.*: Warning (\(.*\)):.*/\1/p" qcom-dtbs.log | sort | uniq -c | sort -nr)

if [ ! -z ${KERNEL_CI_REPO_URL} ]; then
	git push -f ${KERNEL_CI_REPO_URL} ${INTEGRATION_BRANCH}:${KERNEL_CI_BRANCH}
fi

popd

echo "DTBS_WARNINGS=${DTBS_WARNINGS}" > kernel-build_result_variables
