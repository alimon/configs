#!/bin/bash

if [ -e /etc/debian_version ]; then
    echo "deb http://deb.debian.org/debian/ buster-backports main" | sudo tee /etc/apt/sources.list.d/backports.list
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y ansible/buster-backports
    sudo apt purge -y python python2*
else
    sudo dnf -y distrosync
    sudo dnf -y install centos-release-ansible-29
    sudo dnf -y install ansible git
fi

git clone --depth 1 https://git.linaro.org/ci/job/configs.git

cd configs/ldcg-python-pytorch/ansible/

ansible-playbook -i inventory playbooks/build_pytorch.yml
