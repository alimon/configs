#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -f ${HOME}/.vault_pass_erp.txt
}

## Some build dependencies are pre-installed on the build host
# dirmngr virtualenv git sshpass

echo ${ANSIBLE_VAULT} > ${HOME}/.vault_pass_erp.txt

rm -rf ${WORKSPACE}/*

git clone --depth 1 https://github.com/Linaro/erp-test-automation

## Setup environment
virtualenv --python=/usr/bin/python2 erp-test-env
. erp-test-env/bin/activate
pip install ansible future requests

cd erp-test-automation/erp-playbook

# Provision image and run test
ansible-galaxy install -p roles -r requirements.yml
if [ "${BUILD_NUM}" = "latest" ]; then
    ansible-playbook -l ${HOSTS} -e erp_debian_installer_environment=${BUILD_ENV} main.yml
else
    ansible-playbook -l ${HOSTS} -e erp_debian_installer_environment=${BUILD_ENV} -e erp_build_number=${BUILD_NUM} main.yml
fi

# Wait for tests to finish
ansible-playbook -l ${HOSTS} wait-for-poweroff.yml
