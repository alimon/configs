#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -f ${HOME}/.erp/${HOST}/vault_pass.txt
}


rm -rf ${WORKSPACE}/*

git clone --depth 1 https://github.com/Linaro/erp-test-automation
cd erp-test-automation/erp-playbook

# In this matrix build, there is a potential issue to share the same vault password file across hosts. When build fails
# on one host, clearup_exit() will delete the file for safety, but the file may still required by another host. So
# create pass file by host and specify the file with --vault-password-file option by host instread.
sed -i 's|^vault_password_file = ~/.vault_pass_erp.txt|# vault_password_file = ~/.vault_pass_erp.txt|' ansible.cfg
mkdir -p ${HOME}/.erp/${HOST}/
passwd="${HOME}/.erp/${HOST}/vault_pass.txt"
echo ${ANSIBLE_VAULT} > ${passwd}

## Setup environment
# The following build dependencies are pre-installed on the build host
# dirmngr virtualenv git sshpass
virtualenv --python=/usr/bin/python2 erp-test-env
. erp-test-env/bin/activate
pip install -r requirements.txt

# Provision image and run test
ansible-galaxy install -p roles -r requirements.yml
if [ "${BUILD_NUM}" = "latest" ]; then
    ansible-playbook --vault-password-file ${passwd} -l ${HOST} -e erp_installer_environment=${BUILD_ENV} -e erp_installer_distro=${BUILD_DISTRO} main.yml
else
    ansible-playbook --vault-password-file ${passwd} -l ${HOST} -e erp_installer_environment=${BUILD_ENV} -e erp_build_number=${BUILD_NUM} -e erp_installer_distro=${BUILD_DISTRO} main.yml
fi

# Wait for tests to finish
ansible-playbook --vault-password-file ${passwd} -l ${HOST} wait-for-poweroff.yml
