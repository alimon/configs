#!/bin/bash

set -ex

# List of dependencies for builders-deps.sh
[ -z "${pkg_list}" ] && pkg_list="android-tools-fsutils \
          chrpath \
          cpio \
          diffstat \
          gawk \
          libelf-dev \
          libmagickwand-dev \
          libmath-prime-util-perl \
          libsdl1.2-dev \
          libssl-dev \
          pigz \
          pxz \
          python-pip \
          python-requests \
          texinfo \
          vim-tiny \
          virtualenv \
          whiptail"

# apt: Update
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error -- try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi

# apt: Install $pkg_list
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error -- try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

# Python: Install jinja2-cli and ruamel.yaml
pip install --user --force-reinstall jinja2-cli ruamel.yaml

# Install repo
mkdir -p ${HOME}/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
chmod a+x ${HOME}/bin/repo
export PATH=${HOME}/bin:${PATH}
