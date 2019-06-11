#!/bin/bash

set -ex

echo ""
echo "########################################################################"
echo "    Gerrit Environment"
env |grep '^GERRIT'
echo "########################################################################"

git config --global user.name "Linaro CI"
git config --global user.email "ci_notify@linaro.org"

rm -rf ${WORKSPACE}/*

git clone -b ${GERRIT_BRANCH} --depth 2 ssh://git@dev-private-review.linaro.org/${GERRIT_PROJECT} gerrit-project
cd gerrit-project
git fetch ssh://git@dev-private-review.linaro.org/${GERRIT_PROJECT} ${GERRIT_REFSPEC}
git checkout -q FETCH_HEAD
# Overlay changes on top of ci/job/configs
case ${GERRIT_PROJECT} in
	lkft/ci/job/configs)
		cd ..
		git clone --depth 1 https://git.linaro.org/ci/job/configs.git ci-job-configs
		cp -axf -t ci-job-configs gerrit-project/*
		cd ci-job-configs
		git add . && git commit -m "Import changes from ${GERRIT_PROJECT}"
		export GERRIT_PATCHSET_REVISION=$(git rev-parse HEAD)
		;;
esac

export GIT_PREVIOUS_COMMIT=$(git rev-parse HEAD~1)
export GIT_COMMIT=${GERRIT_PATCHSET_REVISION}
jenkins-jobs --version
wget -q https://git.linaro.org/ci/job/configs.git/plain/run-jjb.py -O run-jjb.py
python run-jjb.py

