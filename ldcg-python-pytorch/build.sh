#!/bin/bash

# first let update system
sudo dnf -y distrosync
sudo dnf -y install centos-release-ansible-29
sudo dnf -y install ansible git

git clone --depth 1 https://git.linaro.org/ci/job/configs.git

cd configs/ldcg-python-pytorch/ansible/

ansible-playbook -i inventory playbooks/build_pytorch.yml
