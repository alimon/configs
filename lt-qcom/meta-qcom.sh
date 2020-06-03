#!/bin/bash

set -e

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="python-pip chrpath cpio diffstat gawk libmagickwand-dev libmath-prime-util-perl libsdl1.2-dev libssl-dev python-requests texinfo vim-tiny"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

set -ex

git clone --depth=1 ${POKY_URL} -b ${BRANCH}

cd poky

source oe-init-build-env

mkdir -p ${HOME}/srv/oe/downloads ${HOME}/srv/oe/sstate-cache-${DISTRO}-${BRANCH}
ln -s ${HOME}/srv/oe/downloads
ln -s ${HOME}/srv/oe/sstate-cache-${DISTRO}-${BRANCH} sstate-cache

# get build stats to make sure that we use sstate properly
cat << EOF >> conf/auto.conf
INHERIT += "buildstats buildstats-summary rm_work"
MACHINE := "${MACHINE}"
DISTRO := "${DISTRO}"
TCLIBC := "${TCLIBC}"
EOF

bitbake-layers layerindex-fetch -s -b ${BRANCH} meta-qcom

if [ "${ghprbPullId}" ]; then
    echo "Applying Github pull-request: ${ghprbPullLink}"
    pushd meta-qcom
    git fetch origin refs/pull/${ghprbPullId}/head
    git merge FETCH_HEAD
    popd
fi

bitbake ${IMAGES}
