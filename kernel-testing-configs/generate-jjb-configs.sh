#!/bin/bash -xe

if [[ -z ${KERNEL_BRANCH} || -z ${KERNEL_REPO} || -z ${EMAIL_ADDRESS} ]]; then
	echo "Please make sure parameters are set"
	exit 1
fi

DEVELOPER_JOB_NAME=$(echo ${EMAIL_ADDRESS} | cut -d'@' -f1)-$(sed -s "s/\//-/g" <<< ${KERNEL_BRANCH})

cp templates/trigger-generic.yaml ../trigger-openembedded-lkft-developer-ci-${DEVELOPER_JOB_NAME}.yaml
cp templates/generic.yaml ../openembedded-lkft-developer-ci-${DEVELOPER_JOB_NAME}.yaml

sed -e "s|\${KERNEL_BRANCH}|${KERNEL_BRANCH}|g" -e "s|\${KERNEL_REPO}|${KERNEL_REPO}|g" -e "s|\${EMAIL_ADDRESS}|${EMAIL_ADDRESS}|g" -e "s|\${DEVELOPER_JOB_NAME}|${DEVELOPER_JOB_NAME}|g" -i ../trigger-openembedded-lkft-developer-ci-${DEVELOPER_JOB_NAME}.yaml
sed -e "s|\${KERNEL_BRANCH}|${KERNEL_BRANCH}|g" -e "s|\${KERNEL_REPO}|${KERNEL_REPO}|g" -e "s|\${EMAIL_ADDRESS}|${EMAIL_ADDRESS}|g" -e "s|\${DEVELOPER_JOB_NAME}|${DEVELOPER_JOB_NAME}|g" -e "s|\${QA_SERVER_PROJECT}|${DEVELOPER_JOB_NAME}|g" -i ../openembedded-lkft-developer-ci-${DEVELOPER_JOB_NAME}.yaml


if ! echo "${DUT}" | grep -q "am57xx-evm"; then
	sed -i "/- 'am57xx-evm'/d" ../openembedded-lkft-developer-ci-${DEVELOPER_JOB_NAME}.yaml
fi
if  ! echo "${DUT}" | grep -q "dragonboard-410c"; then
	sed -i "/- 'dragonboard-410c'/d" ../openembedded-lkft-developer-ci-${DEVELOPER_JOB_NAME}.yaml
fi

if ! echo "${DUT}" | grep -q "hikey"; then
	sed -i "/- 'hikey'/d" ../openembedded-lkft-developer-ci-${DEVELOPER_JOB_NAME}.yaml
fi
if ! echo "${DUT}" | grep -q "intel-core2-32"; then
	sed -i "/- 'intel-core2-32'/d" ../openembedded-lkft-developer-ci-${DEVELOPER_JOB_NAME}.yaml
fi
if ! echo "${DUT}" | grep -q "intel-corei7-64"; then
	sed -i "/- 'intel-corei7-64'/d" ../openembedded-lkft-developer-ci-${DEVELOPER_JOB_NAME}.yaml
fi
if ! echo "${DUT}" | grep -q "juno"; then
	sed -i "/- 'juno'/d" ../openembedded-lkft-developer-ci-${DEVELOPER_JOB_NAME}.yaml
fi

git add ../openembedded-lkft-developer-ci-${DEVELOPER_JOB_NAME}.yaml ../  ../trigger-openembedded-lkft-developer-ci-${DEVELOPER_JOB_NAME}.yaml
git commit -m "Added new jobs for ${DEVELOPER_JOB_NAME}"
wget https://raw.githubusercontent.com/vishalbhoj/tools/master/squad/create_project.py
python create_project.py -p ${DEVELOPER_JOB_NAME} -g lkft -s ${EMAIL_ADDRESS}
