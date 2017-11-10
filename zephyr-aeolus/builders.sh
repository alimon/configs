#!/bin/bash

sudo apt-get -q=2 update
sudo apt-get -q=2 -y install ccache g++-multilib gcc-arm-none-eabi git \
    python3-pip python-requests python-serial python3-serial python3-ply \
    python3-yaml python3-setuptools python3-wheel socat rsync device-tree-compiler

set -ex

# Distro package is too old for Zephyr
sudo pip3 install pyelftools pykwalify
# CMake is pre-installed
#cmake_version=3.9.5
#wget -q https://cmake.org/files/v3.9/cmake-${cmake_version}-Linux-x86_64.tar.gz
#tar xf cmake-${cmake_version}-Linux-x86_64.tar.gz
#cp -a cmake-${cmake_version}-Linux-x86_64/bin/* /usr/local/bin/
#cp -a cmake-${cmake_version}-Linux-x86_64/share/* /usr/local/share/
#rm -rf cmake-${cmake_version}-Linux-x86_64
#cmake -version

git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools ${HOME}/depot_tools
PATH=${HOME}/depot_tools:${PATH}
git clone --depth 1 https://git.linaro.org/lite/linaro-aeolus.git ${WORKSPACE}
git-retry submodule sync --recursive
git-retry submodule update --init --recursive --checkout
git clean -fdx
echo "GIT_COMMIT=$(git rev-parse --short=8 HEAD)" > env_var_parameters

# Toolchains are pre-installed and come from:
# https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/6-2017q2/gcc-arm-none-eabi-6-2017-q2-update-linux.tar.bz2
# https://github.com/zephyrproject-rtos/meta-zephyr-sdk/releases/download/0.9.2/zephyr-sdk-0.9.2-setup.run
# To install Zephyr SDK: ./zephyr-sdk-0.9.2-setup.run --quiet --nox11 -- <<< "${HOME}/srv/toolchain/zephyr-sdk-0.9.2"

case "${ZEPHYR_GCC_VARIANT}" in
  gccarmemb)
    export GCCARMEMB_TOOLCHAIN_PATH="${HOME}/srv/toolchain/gcc-arm-none-eabi-6-2017-q2-update"
  ;;
  zephyr)
    mkdir -p ${HOME}/opt
    ln -sf ${HOME}/srv/toolchain/zephyr-sdk-0.9.2 ${HOME}/opt/zephyr-sdk-0.9.2
    export ZEPHYR_SDK_INSTALL_DIR="${HOME}/opt/zephyr-sdk-0.9.2"
  ;;
esac

# Set build environment variables
LANG=C
ZEPHYR_BASE=${WORKSPACE}
PATH=${ZEPHYR_BASE}/scripts:${PATH}
export LANG ZEPHYR_BASE PATH
CCACHE_DIR="${HOME}/srv/ccache"
CCACHE_UNIFY=1
CCACHE_SLOPPINESS=file_macro,include_file_mtime,time_macros
USE_CCACHE=1
export CCACHE_DIR CCACHE_UNIFY CCACHE_SLOPPINESS USE_CCACHE
env |grep '^ZEPHYR'

echo ""
echo "########################################################################"
echo "    Build"
echo "########################################################################"

make_wrapper=zmake
[ "${PROJECT}" = "zephyr.js" ] && make_wrapper=zmake-z.js
bash -x ${make_wrapper} ${PROJECT} BOARD=${PLATFORM}

cd ${WORKSPACE}
mkdir -p out/${PLATFORM}
mv ${PROJECT}-${PLATFORM}-*.bin ${PROJECT}-${PLATFORM}-*.elf out/${PLATFORM}/

CCACHE_DIR=${CCACHE_DIR} ccache -M 30G
CCACHE_DIR=${CCACHE_DIR} ccache -s
