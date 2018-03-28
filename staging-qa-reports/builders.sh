#!/bin/bash

set -e

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -f ${HOME}/.ansible-vault-passwd
}

banner() {
    echo
    echo "$@" | sed -e 's/./-/g'
    echo "$@"
    echo "$@" | sed -e 's/./-/g'
    echo
}

banner "Install required Debian packages"
echo "deb http://deb.debian.org/debian stretch-backports main" > stretch-backports.list
sudo mv stretch-backports.list /etc/apt/sources.list.d/

sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update
sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y \
  git moreutils unzip wget python3-setuptools python3-wheel
sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y \
  -t stretch-backports ansible

banner "Build squad package"
rm -rf build dist
./scripts/git-build
pkg=$(basename dist/*.whl)

banner "Deploy"
cp -a dist/${pkg} qa-reports.linaro.org/ansible
cd qa-reports.linaro.org/ansible/
echo "${ANSIBLE_VAULT_PASSWORD}" > ${HOME}/.ansible-vault-passwd
./deploy staging --vault-password-file ~/.ansible-vault-passwd --extra-vars squad=${pkg} site.yml
