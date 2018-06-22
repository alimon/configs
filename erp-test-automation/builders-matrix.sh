#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -f ${HOME}/.erp/${HOST}/vault_pass.txt
}


rm -rf ${WORKSPACE}/*

## Setup environment
# The following build dependencies are pre-installed on the build host
# dirmngr virtualenv git sshpass
virtualenv --python=/usr/bin/python2 venv
. venv/bin/activate

git clone --depth 1 https://github.com/Linaro/erp-test-automation
cd erp-test-automation/erp-playbook
pip install -r requirements.txt

# In this matrix build, there is a potential issue to share the same vault password file across hosts. When build fails
# on one host, clearup_exit() will delete the file for safety, but the file may still required by another host. So
# create pass file by host and specify the file with --vault-password-file option by host instead.
sed -i 's|^vault_password_file = ~/.vault_pass_erp.txt|# vault_password_file = ~/.vault_pass_erp.txt|' ansible.cfg
mkdir -p ${HOME}/.erp/${HOST}/
passwd="${HOME}/.erp/${HOST}/vault_pass.txt"
echo ${ANSIBLE_VAULT} > ${passwd}

# Image upload is enabled by default in ansible role. It only upload image when it is not exist yet in mr-provisioner's
# database. However, matrix build erp-test-automation-matrix run the same ansible playbook on multiple platforms in
# parallel almost in the same time, means image existence query responds for all of these threads will be 'not exist
# yet', which causes that the same image will be uploaded up to the number of platforms times. To break the race
# condition, the following line postpone test run on all platforms except d05 10 minutes which should be more then
# enough for the d05 to finish image upload.
[ "${HOST}" = "j12-d05-01" ] || sleep 600

# Provision image and run test
ansible-galaxy install -p roles -r requirements.yml
if [ "${BUILD_NUM}" = "latest" ]; then
    ansible-playbook --vault-password-file ${passwd} -l ${HOST} -e erp_installer_environment=${BUILD_ENV} -e erp_installer_distro=${BUILD_DISTRO} main.yml
else
    ansible-playbook --vault-password-file ${passwd} -l ${HOST} -e erp_installer_environment=${BUILD_ENV} -e erp_build_number=${BUILD_NUM} -e erp_installer_distro=${BUILD_DISTRO} main.yml
fi

# Wait for tests to finish
ansible-playbook --vault-password-file ${passwd} -l ${HOST} wait-for-poweroff.yml
