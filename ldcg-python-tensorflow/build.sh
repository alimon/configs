#!/bin/bash

set -xe

rm -rf ${WORKSPACE}/*

if [ -e /etc/debian_version ]; then
    echo "deb http://deb.debian.org/debian/ buster-backports main" | sudo tee /etc/apt/sources.list.d/backports.list
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y ansible/buster-backports
else
    sudo dnf -y distrosync
    sudo dnf -y install centos-release-ansible-29
    sudo dnf -y install ansible git python36
fi

git clone --depth 1 https://git.linaro.org/ci/job/configs.git

cd configs/ldcg-python-tensorflow/tensorflow

# 00:01:34.515 + '[' ldcg-python-tensorflow-nightly/nodes=docker-buster-arm64-leg == ldcg-python-tensorflow-nightly ']'

if [ `echo $JOB_NAME | cut -d'/' -f1` == 'ldcg-python-tensorflow-nightly' ]; then
    ansible-playbook -i inventory playbooks/run-git.yml
else
    ansible-playbook -i inventory playbooks/run.yml
fi
