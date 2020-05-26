#!/bin/bash

set -ex

function build_integration_kernel()
{
	export ARCH=$1
	export KERNEL_CONFIGS=$2

	source install-gcc-toolchain.sh
	export CROSS_COMPILE="ccache $(basename $(ls -1 ${tcbindir}/*-gcc) gcc)"
	export PATH=${tcbindir}:$PATH

	make distclean
	make ${KERNEL_CONFIGS}

	# build QCOM DTBS with warnings
	if [ "$ARCH" = "arm64" ]; then
		make W=1 arch/$ARCH/boot/dts/qcom/  2>&1 | tee -a qcom-dtbs.log
	elif [ "$ARCH" = "arm" ]; then
		make W=1 arch/$ARCH/boot/dts/  2>&1 | tee -a qcom-dtbs.log
	fi
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

wget https://git.linaro.org/ci/job/configs.git/plain/lt-qcom/install-gcc-toolchain.sh
build_integration_kernel "arm" "multi_v7_defconfig"
build_integration_kernel "arm64" "defconfig"

# record QCOM DTBS warnings, for all builds
DTBS_WARNINGS=$(sed -n "s/.*: Warning (\(.*\)):.*/\1/p" qcom-dtbs.log | sort | uniq -c | sort -nr | sed ':a;N;$!ba;s/\n/\\n\\\n/g')

if [ ! -z ${KERNEL_CI_REPO_URL} ]; then
	git push -f ${KERNEL_CI_REPO_URL} ${INTEGRATION_BRANCH}:${KERNEL_CI_BRANCH}
fi

popd

echo "DTBS_WARNINGS=${DTBS_WARNINGS}" > kernel-build_result_variables
