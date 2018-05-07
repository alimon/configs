#!/bin/bash

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

QCOMLT_CONFIG_PATH=${PWD}/$(basename ${QCOMLT_CONFIG_REPO_URL})
git clone -v ${QCOMLT_CONFIG_REPO_URL} ${QCOMLT_CONFIG_PATH}

cd ${QCOMLT_CONFIG_PATH}
CURRENT_REVISION=$(git rev-parse --short HEAD)
python ./bin/automerge2repo.py automerge-ci.conf automerge-ci.xml
git add automerge-ci.xml

git commit -s -m "automerge-ci.xml: Update based on rev ${CURRENT_REVISION}" automerge-ci.xml
echo "Pusing new version of automerge-ci.xml to ${QCOMLT_CONFIG_REPO_URL} ${QCOMLT_CONFIG_BRANCH}..."
git push ${QCOMLT_CONFIG_REPO_URL} master:${QCOMLT_CONFIG_BRANCH} -f

exit 0
