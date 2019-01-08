#!/bin/bash

echo "Starting ${JOB_NAME} with the following parameters:"
echo "AUTOMERGE_REPO_URL: ${AUTOMERGE_REPO_URL}"
echo "AUTOMERGE_BRANCH: ${AUTOMERGE_BRANCH}"
echo "CONFIG_REPO_URL: ${CONFIG_REPO_URL}"
echo "CONFIG_BRANCH: ${CONFIG_BRANCH}"
echo "KERNEL_REPO_URL: ${KERNEL_REPO_URL}"
echo "INTEGRATION_REPO_URL: ${INTEGRATION_REPO_URL}"
echo "INTEGRATION_BRANCH: ${INTEGRATION_BRANCH}"
echo "KERNEL_CI_REPO_URL: ${KERNEL_CI_REPO_URL}"
echo "KERNEL_CI_BRANCH: ${KERNEL_CI_BRANCH}"

set -ex

git config --global user.name "Linaro CI"
git config --global user.email "ci_notify@linaro.org"
git config --global core.sshCommand "ssh -F ${HOME}/qcom.sshconfig"

cat << EOF > ${HOME}/qcom.sshconfig
Host git.linaro.org
    User git
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
EOF
chmod 0600 ${HOME}/qcom.sshconfig

# Use a persistent storage to avoid clone every time the integration repository
PERSISTENT_PATH=${HOME}/srv/qcomlt/linux_automerge
mkdir -p ${PERSISTENT_PATH}
KERNEL_REPO_BARE_PATH=${PERSISTENT_PATH}/$(basename ${KERNEL_REPO_URL})
if [ -d "${KERNEL_REPO_BARE_PATH}" ]; then
	echo "Updating kernel bare repo ..."
	pushd $(pwd)
	cd ${KERNEL_REPO_BARE_PATH}
	git fetch --all -v
	git update-server-info
	popd
else
	echo "Cloning integration bare repo ..."
	git clone --bare ${KERNEL_REPO_URL} ${KERNEL_REPO_BARE_PATH}
fi
INTEGRATION_REPO_PATH=$(pwd)/$(basename ${INTEGRATION_REPO_URL})
echo "Cloning integration repo ..."
git clone ${KERNEL_REPO_BARE_PATH} ${INTEGRATION_REPO_PATH}

pushd $(pwd)
export INTG_REMOTE=automerge-intg
cd ${INTEGRATION_REPO_PATH}

git remote add ${INTG_REMOTE} ${INTEGRATION_REPO_URL}
git fetch ${INTG_REMOTE}
set +e
git branch -a | grep "remotes/${INTG_REMOTE}/${INTEGRATION_BRANCH}$"
branch_exists=$?
set -e
if [ $branch_exists -ne 0 ]; then
	echo "Creating initial integration branch ..."
	git push ${INTG_REMOTE} HEAD:${INTEGRATION_BRANCH}
	git fetch -v ${INTG_REMOTE}
fi
git checkout -b ${INTEGRATION_BRANCH} ${INTG_REMOTE}/${INTEGRATION_BRANCH}
popd

echo "Initializing automerge execution ..."
pushd $(pwd)
AUTOMERGE_PATH=$(pwd)/automerge
git clone ${AUTOMERGE_REPO_URL} -b ${AUTOMERGE_BRANCH} ${AUTOMERGE_PATH}
export PATH=${AUTOMERGE_PATH}:$PATH

cd ${AUTOMERGE_PATH}
export CONFIG_PATH=''
if [ ! -z ${CONFIG_REPO_URL} ]; then
	export CONFIG_REPO_PATH=${AUTOMERGE_PATH}/$(basename ${CONFIG_REPO_URL})
	git clone ${CONFIG_REPO_URL} -b ${CONFIG_BRANCH} ${CONFIG_REPO_PATH}

	if [ -f ${CONFIG_REPO_PATH}/automerge-ci.conf ]; then
		export CONFIG_PATH=${CONFIG_REPO_PATH}/automerge-ci.conf
	fi
fi

if [ -f ${CONFIG_PATH} ]; then
	echo "Using configuration from repository"
	cat ${CONFIG_PATH}
else
	echo "Using default configuration"
	cat <<EOF > automerge-ci.conf
baseline git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git master
EOF

	export CONFIG_PATH=${AUTOMERGE_PATH}/automerge-ci.conf
fi

AUTOMERGE_CONFIG=$(sed ':a;N;$!ba;s/\n/\\n\\\n/g' ${CONFIG_PATH})

# * Disable exit when fail to collect automerge_result_variables for builders-kernel.sh and email
# * TODO: Add support in ci-merge to create a log (instead of use tee)
set +e
set -o pipefail
ci-merge -l ${INTEGRATION_REPO_PATH} -r ${INTEGRATION_REPO_URL} -i ${INTEGRATION_BRANCH} -c ${RERERE_REPO_URL} -n | tee automerge.log
AUTOMERGE_EXIT_CODE=$?
set +o pipefail
AUTOMERGE_BRANCH_FAILED=$(grep 'Merge failed' automerge.log | sed ':a;N;$!ba;s/\n/\\n\\\n/g')
set -e
popd

echo "AUTOMERGE_CONFIG=${AUTOMERGE_CONFIG}" > automerge_result_variables
echo "AUTOMERGE_BRANCH_FAILED=${AUTOMERGE_BRANCH_FAILED}" >> automerge_result_variables
echo "AUTOMERGE_EXIT_CODE=${AUTOMERGE_EXIT_CODE}" >> automerge_result_variables
echo "INTEGRATION_REPO_PATH=${INTEGRATION_REPO_PATH}" >> automerge_result_variables
