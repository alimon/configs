#!/bin/bash
set -ex

sudo apt-get -q=2 update
#sudo apt-get -q=2 -y install git g++ libc6-dev-i386 g++-multilib python3-ply python3-yaml gcc-arm-none-eabi python-requests rsync device-tree-compiler
sudo apt-get -q=2 -y install python3-pip python-serial python3-serial socat

# pip as shipped by distro may be not up to date enough to support some
# quirky PyPI packages, specifically cmake was caught like that.
sudo pip3 install --upgrade pip

sudo pip3 install pyelftools
# Zephyr requires very recent version of CMake. Strangely enough, such
# can be installed from PyPI.
sudo pip3 install cmake

git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools ${HOME}/depot_tools
PATH=${HOME}/depot_tools:${PATH}
git clone --depth 1 ${GIT_URL} -b ${BRANCH} ${WORKSPACE}
git-retry submodule sync --recursive
git-retry submodule update --init --recursive --checkout
git clean -fdx
echo "GIT_COMMIT=$(git rev-parse --short=8 HEAD)" > env_var_parameters

# Toolchains are pre-installed and come from:
# https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2
# https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.10.0/zephyr-sdk-0.10.0-setup.run
# To install Zephyr SDK: ./zephyr-sdk-0.10.0-setup.run --quiet --nox11 -- <<< "${HOME}/srv/toolchain/zephyr-sdk-0.10.0"

case "${ZEPHYR_GCC_VARIANT}" in
  gccarmemb)
    export GCCARMEMB_TOOLCHAIN_PATH="${HOME}/srv/toolchain/gcc-arm-none-eabi-7-2018-q2-update"
  ;;
  zephyr)
    export ZEPHYR_SDK_INSTALL_DIR="${HOME}/srv/toolchain/zephyr-sdk-0.10.0"
  ;;
esac

# Set build environment variables
LANG=C
ZEPHYR_BASE=${WORKSPACE}
PATH=${ZEPHYR_BASE}/scripts:${PATH}
OUTDIR=${HOME}/srv/zephyr/${ZEPHYR_GCC_VARIANT}/${PLATFORM}
export LANG ZEPHYR_BASE PATH
CCACHE_DIR="${HOME}/srv/ccache"
CCACHE_UNIFY=1
CCACHE_SLOPPINESS=file_macro,include_file_mtime,time_macros
USE_CCACHE=1
export CCACHE_DIR CCACHE_UNIFY CCACHE_SLOPPINESS USE_CCACHE
env |grep '^ZEPHYR'
python3 -c "import sys; print(sys.getdefaultencoding())"

echo ""
echo "########################################################################"
echo "    Build"
echo "########################################################################"

