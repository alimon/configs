#!/bin/bash

# first let update system
sudo dnf -y distrosync
sudo dnf -y install centos-release-ansible-29
sudo dnf -y install ansible git

git clone --depth 1 https://git.linaro.org/ci/job/configs.git

cd configs/ldcg-hpc-tensorflow/tensorflow

echo "[all]" > inventory
echo "localhost ansible_connection=local" >> inventory

ansible-playbook -i inventory playbooks/run.yml
