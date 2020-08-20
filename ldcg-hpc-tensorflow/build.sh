#!/bin/bash

# first let update system
sudo dnf -y distrosync
sudo dnf -y install centos-release-ansible-29
sudo dnf -y install ansible

cd tensorflow
ansible-playbook -i inventory playbooks/run.yml
