#!/bin/bash

sudo apt-get -q=2 update
sudo apt-get -q=2 -y install ccache cmake g++-multilib gcc-arm-none-eabi git \
    python-requests python-serial python3-serial python3-ply \
    python3-yaml socat rsync device-tree-compiler \
    python3-crypto python3-pyasn1 python3-ecdsa python3-pip

pip3 install --user pyelftools

set -ex

echo "Current directory: "
pwd
echo "Environment"
env

# Build starts out in ${WORKSPACE}
# Clean any previous runs.
rm -rf ${WORKSPACE}/zephyr
rm -rf ${WORKSPACE}/mcuboot

git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools ${HOME}/depot_tools
PATH=${HOME}/depot_tools:${PATH}
git clone --depth 1 https://github.com/zephyrproject-rtos/zephyr ${WORKSPACE}/zephyr
git clone --depth 1 https://github.com/runtimeco/mcuboot ${WORKSPACE}/mcuboot
# (cd ${WORKSPACE}/mcuboot; git fetch origin pull/85/head; git checkout -b pull85 FETCH_HEAD)
echo "GIT_COMMIT=$(git rev-parse --short=8 HEAD)" > env_var_parameters

# Toolchains are pre-installed and come from:
# https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/6-2017q2/gcc-arm-none-eabi-6-2017-q2-update-linux.tar.bz2
# https://github.com/zephyrproject-rtos/meta-zephyr-sdk/releases/download/0.9.1/zephyr-sdk-0.9.1-setup.run
# To install Zephyr SDK: ./zephyr-sdk-0.9.1-setup.run --quiet --nox11 -- <<< "${HOME}/srv/toolchain/zephyr-sdk-0.9.1"

case "${ZEPHYR_GCC_VARIANT}" in
  gccarmemb)
    export GCCARMEMB_TOOLCHAIN_PATH="${HOME}/srv/toolchain/gcc-arm-none-eabi-6-2017-q2-update"
  ;;
  zephyr)
    mkdir -p ${HOME}/opt
    ln -sf ${HOME}/srv/toolchain/zephyr-sdk-0.9.1 ${HOME}/opt/zephyr-sdk-0.9.1
    export ZEPHYR_SDK_INSTALL_DIR="${HOME}/opt/zephyr-sdk-0.9.1"
  ;;
esac

# Set build environment variables
LANG=C
ZEPHYR_BASE=${WORKSPACE}/zephyr
export ZEPHYR_GCC_VARIANT=zephyr
PATH=${ZEPHYR_BASE}/scripts:${PATH}
export LANG ZEPHYR_BASE PATH
#CCACHE_DIR="${HOME}/srv/ccache"
#CCACHE_UNIFY=1
#CCACHE_SLOPPINESS=file_macro,include_file_mtime,time_macros
#USE_CCACHE=1
#export CCACHE_DIR CCACHE_UNIFY CCACHE_SLOPPINESS USE_CCACHE
env |grep '^ZEPHYR'

echo ""
echo "########################################################################"
echo "    Build"
echo "########################################################################"

# make_wrapper=zmake
# [ "${PROJECT}" = "zephyr.js" ] && make_wrapper=zmake-z.js
# bash -x ${make_wrapper} ${PROJECT} BOARD=${PLATFORM}

cd ${WORKSPACE}
source zephyr/zephyr-env.sh
cd ${WORKSPACE}/mcuboot/samples/zephyr
make full.bin BOARD=${PLATFORM}

cd ${WORKSPACE}
mkdir -p out/${PLATFORM}
# TODO: Get a timestamp or something in this artifact.
mv mcuboot/samples/zephyr/full.bin ${WORKSPACE}/out/${PLATFORM}

#CCACHE_DIR=${CCACHE_DIR} ccache -M 30G
#CCACHE_DIR=${CCACHE_DIR} ccache -s
