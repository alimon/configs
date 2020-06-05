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

# When testing a Github PR, use the appropriate target branch
if [ "${ghprbPullId}" ]; then
BRANCH=${ghprbTargetBranch}
fi

git clone --depth=1 ${POKY_URL} -b ${BRANCH}

cd poky

source oe-init-build-env

mkdir -p ${HOME}/srv/oe/downloads ${HOME}/srv/oe/sstate-cache-${DISTRO}-${BRANCH}
ln -s ${HOME}/srv/oe/downloads
ln -s ${HOME}/srv/oe/sstate-cache-${DISTRO}-${BRANCH} sstate-cache

# get build stats to make sure that we use sstate properly
cat << EOF >> conf/auto.conf
INHERIT += "buildstats buildstats-summary"
MACHINE := "${MACHINE}"
DISTRO := "${DISTRO}"
TCLIBC := "${TCLIBC}"
EOF

# When testing a PR, use the already checkout meta-qcom, it contains the PR to test
if [ "${ghprbPullId}" ]; then
    cat >> conf/bblayers.conf <<EOF
BBLAYERS += "${WORKSPACE}/meta-qcom"
EOF

# otherwise get layer information from the layer index
else
    bitbake-layers layerindex-fetch -s -b ${BRANCH} meta-qcom
fi

bitbake ${IMAGES}
