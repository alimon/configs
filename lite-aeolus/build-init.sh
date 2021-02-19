#!/bin/bash
set -ex

# Zephyr 2.2+ requires Python3.6. As it's not available in official distro
# packages for Ubuntu Xenial (16.04) which we use, install it from PPA.
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get -q=2 update
sudo apt-get install -y python3.6
sudo ln -sf python3.6 /usr/bin/python3

#sudo apt-get -q=2 -y install git g++ libc6-dev-i386 g++-multilib python3-ply python3-yaml gcc-arm-none-eabi python-requests rsync device-tree-compiler
sudo apt-get -q=2 -y install python3-pip python-serial python3-serial socat

# pip as shipped by distro may be not up to date enough to support some
# quirky PyPI packages, specifically cmake was caught like that.
sudo pip3 install --upgrade pip

sudo pip3 install pyelftools
# Zephyr requires very recent version of CMake. Strangely enough, such
# can be installed from PyPI.
sudo pip3 install cmake

sudo pip3 install west
west --version

python --version
/usr/bin/env python --version
python3 --version

git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools ${HOME}/depot_tools
PATH=${HOME}/depot_tools:${PATH}
git clone --depth 1 ${GIT_URL} -b ${BRANCH} ${WORKSPACE}
(cd ${WORKSPACE}; git describe --always)

# We used to call git-retry shell wrapper, until it started to choose
# a wrong Python interpreter. "_" below is a param ignored when executing
# git_retry.py directly.
python ${HOME}/depot_tools/git_retry.py _ submodule sync --recursive
python ${HOME}/depot_tools/git_retry.py _ submodule update --init --recursive --checkout

git clean -fdx
echo "GIT_COMMIT_ID=$(git rev-parse --short=8 HEAD)" > env_var_parameters
# Build ID to use in external systems, like LAVA/SQUAD. Should include
# ${BUILD_NUMBER}, to avoid mixing up results of different builds of the
# same project git revision.
echo "EXTERNAL_BUILD_ID=$(git rev-parse --short=8 HEAD)-${BUILD_NUMBER}" >> env_var_parameters

# Toolchains are pre-installed by 'zephyr-upstream' job and come from:
# https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/9-2019q4/gcc-arm-none-eabi-9-2019-q4-major-x86_64-linux.tar.bz2
# https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.12.3/zephyr-sdk-0.12.3-setup.run
# To install Zephyr SDK: ./zephyr-sdk-0.12.3-setup.run --quiet --nox11 -- <<< "${HOME}/srv/toolchain/zephyr-sdk-0.12.3"

case "${ZEPHYR_TOOLCHAIN_VARIANT}" in
  gccarmemb)
    export GCCARMEMB_TOOLCHAIN_PATH="${HOME}/srv/toolchain/gcc-arm-none-eabi-9-2019-q4-major"
  ;;
  zephyr)
    export ZEPHYR_SDK_INSTALL_DIR="${HOME}/srv/toolchain/zephyr-sdk-0.12.3"
  ;;
esac

# Set build environment variables
LANG=C
ZEPHYR_BASE=${WORKSPACE}
PATH=${ZEPHYR_BASE}/scripts:${PATH}
OUTDIR=${HOME}/srv/zephyr/${ZEPHYR_TOOLCHAIN_VARIANT}/${PLATFORM}
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

