#!/bin/bash

sudo apt-get -q=2 update
sudo apt-get -q=2 -y install ccache cmake g++-multilib gcc-arm-none-eabi git libc6-dev-i386 python-pycurl python-requests python3-ply rsync

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
  cd ${WORKSPACE}
  rm -rf out
}

git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools ${HOME}/depot_tools
PATH=${HOME}/depot_tools:${PATH}
git clone --depth 1 https://git.linaro.org/lite/linaro-aeolus.git ${WORKSPACE}
git-retry submodule sync --recursive
git-retry submodule update --init --recursive --checkout
git clean -fdx
echo "GIT_COMMIT=$(git rev-parse --short=8 HEAD)" > env_var_parameters

# Toolchains are pre-installed and come from:
# https://launchpad.net/gcc-arm-embedded/5.0/5-2016-q3-update/+download/gcc-arm-none-eabi-5_4-2016q3-20160926-linux.tar.bz2
# https://nexus.zephyrproject.org/content/repositories/releases/org/zephyrproject/zephyr-sdk/0.8.2-i686/zephyr-sdk-0.8.2-i686-setup.run
# To install Zephyr SDK: ./zephyr-sdk-0.8.2-i686-setup.run --quiet --nox11 -- <<< "${HOME}/srv/toolchain/zephyr-sdk-0.8.2"

case "${ZEPHYR_GCC_VARIANT}" in
  gccarmemb)
    export GCCARMEMB_TOOLCHAIN_PATH="${HOME}/srv/toolchain/gcc-arm-none-eabi-5_4-2016q3"
  ;;
  zephyr)
    mkdir -p ${HOME}/opt
    ln -sf ${HOME}/srv/toolchain/zephyr-sdk-0.8.2 ${HOME}/opt/zephyr-sdk-0.8.2
    export ZEPHYR_SDK_INSTALL_DIR="${HOME}/opt/zephyr-sdk-0.8.2"
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
mv ${PROJECT}-${PLATFORM}-*.bin out/${PLATFORM}/

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
# pycurl based
#wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
# python-requests based
wget -q https://raw.githubusercontent.com/pfalcon/publishing-api/pfalcon/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --api_version 3 \
  --link-latest \
  out/${PLATFORM} components/kernel/aeolus/${ZEPHYR_GCC_VARIANT}/${PROJECT}/${PLATFORM}/${BUILD_NUMBER}

CCACHE_DIR=${CCACHE_DIR} ccache -M 30G
CCACHE_DIR=${CCACHE_DIR} ccache -s
