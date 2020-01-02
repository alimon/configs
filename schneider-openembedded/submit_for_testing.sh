#!/bin/bash

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git
pushd configs
git log -1
popd

# Used by DB410C's template:
export RESIZE_ROOTFS=${RESIZE_ROOTFS:-}

templates_common=(\
	uboot.yaml \
	tftp-nfs.yaml \
	tftp-nfs-dev.yaml \
	wic.yaml \
	wic-dev.yaml \
	wic-dev-ltp-ptest.yaml \
)

templates_soca9=(\
)

templates_rzn1d=(\
	ubi.yaml \
	ubi-edge.yaml \
	wic-edge.yaml \
)

if [ "${DEVICE_TYPE}" == "rzn1d" ]; then
	templates=( ${templates_common[@]} ${templates_rzn1d[@]} )
else
	templates=( ${templates_common[@]} ${templates_soca9[@]} )
fi

for template in ${templates[@]};
do
	python configs/openembedded-lkft/submit_for_testing.py \
	  --device-type ${DEVICE_TYPE} \
	  --build-number ${BUILD_NUMBER} \
	  --lava-server ${LAVA_SERVER} \
	  --qa-server ${QA_SERVER} \
	  --qa-server-team ${QA_SERVER_TEAM} \
	  --qa-server-project ${QA_SERVER_PROJECT} \
	  --git-commit ${MANIFEST_COMMIT} \
	  --template-path configs/schneider-openembedded/lava-job-definitions/ \
	  --template-names ${template}
done
