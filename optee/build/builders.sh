#!/bin/bash

set -e

sudo dpkg --add-architecture i386
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
# Install packages mentioned in the main README.md
pkg_list="android-tools-adb android-tools-fastboot autoconf automake bc bison"
pkg_list+=" build-essential ccache cscope curl device-tree-compiler flex"
pkg_list+=" ftp-upload gdisk git iasl libattr1-dev libc6:i386 libcap-dev"
pkg_list+=" libfdt-dev libftdi-dev libglib2.0-dev libhidapi-dev libncurses5-dev"
pkg_list+=" libpixman-1-dev libssl-dev libstdc++6:i386 libtool libz1:i386"
pkg_list+=" mtools netcat python-crypto python-requests python-serial"
pkg_list+=" unzip uuid-dev xdg-utils xterm xz-utils zlib1g-dev zip"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

CCACHE_DIR="${HOME}/srv/ccache"
CCACHE_UNIFY=1
CCACHE_SLOPPINESS=file_macro,include_file_mtime,time_macros
PATH=/usr/lib/ccache:${PATH}
export CCACHE_DIR CCACHE_UNIFY CCACHE_SLOPPINESS PATH

# Store the home repository
if [ -z "${WORKSPACE}" ]; then
  # Local build
  export WORKSPACE=${PWD}
fi

export JENKINS_WORKSPACE=${WORKSPACE}
unset WORKSPACE
export make="make -j$(nproc) -s"

# Tools required
mkdir -p ${HOME}/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo && chmod a+x ${HOME}/bin/repo
export PATH=${HOME}/bin:${PATH}

echo "INFO: Building OP-TEE for ${repo_proj}"
mkdir -p ${JENKINS_WORKSPACE}/${repo_proj}

if [ "${repo_proj}" == "fvp" ]; then
  mkdir -p ${JENKINS_WORKSPACE}/${repo_proj}/Foundation_Platformpkg
fi

(cd ${JENKINS_WORKSPACE}/${repo_proj} && repo init -u https://github.com/OP-TEE/manifest.git -m ${repo_proj}.xml < /dev/null && repo sync --no-clone-bundle --no-tags --quiet -j$(nproc))

# Fetch a local copy of dtc+libfdt to avoid issues with a possibly outdated libfdt-dev
# DTC (libfdt) version >= 1.4.2 is required
if [ "${repo_proj}" == "qemu_v8" ]; then
  (cd ${JENKINS_WORKSPACE}/${repo_proj}/qemu && git submodule update --init dtc)
fi

(cd ${JENKINS_WORKSPACE}/${repo_proj}/build && ${make} -f toolchain.mk toolchains && ${make} all)
