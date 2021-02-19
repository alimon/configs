#!/bin/bash

echo "Going to build:"
echo "git branch: ${BRANCH}"
echo "git revision: ${GIT_COMMIT}"
echo "Root build cause: ${ROOT_BUILD_CAUSE}"
echo

# Zephyr 2.2+ requires Python3.6. As it's not available in official distro
# packages for Ubuntu Xenial (16.04) which we use, install it from PPA.
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get -q=2 update
sudo apt-get install -y python3.6
sudo ln -sf python3.6 /usr/bin/python3

sudo apt-get -q=2 -y install git ninja-build g++ g++-multilib gperf python3-ply \
    gcc-arm-none-eabi python-requests rsync device-tree-compiler \
    python3-pip python3-serial python3-setuptools python3-wheel \
    python3-requests util-linux srecord

set -ex

# pip as shipped by distro may be not up to date enough to support some
# quirky PyPI packages, specifically cmake was caught like that.
sudo pip3 install --upgrade pip

sudo pip3 install west
west --version

# Distro package is too old for Zephyr
sudo pip3 install pyelftools

# Pre-installed CMake is too old for the latest Zephyr
# Recent recommendation to users is to install it via PyPI, let'd do the same
sudo pip3 install cmake
#cmake_version=3.9.5
#wget -q https://cmake.org/files/v3.9/cmake-${cmake_version}-Linux-x86_64.tar.gz
#tar xf cmake-${cmake_version}-Linux-x86_64.tar.gz
#cp -a cmake-${cmake_version}-Linux-x86_64/bin/* /usr/local/bin/
#cp -a cmake-${cmake_version}-Linux-x86_64/share/* /usr/local/share/
#rm -rf cmake-${cmake_version}-Linux-x86_64
#cmake -version


git clone -b ${BRANCH} https://github.com/zephyrproject-rtos/zephyr.git
west init -l zephyr/
west update

cd zephyr
git clean -fdx
if [ -n "${GIT_COMMIT}" ]; then
  git checkout ${GIT_COMMIT}
fi
echo "GIT_COMMIT_ID=$(git rev-parse --short=8 HEAD)" > ${WORKSPACE}/env_var_parameters

head -5 Makefile

# Note that Zephyr SDK is needed even when building with the gnuarmemb
# toolchain, ZEPHYR_SDK_INSTALL_DIR is needed to find things like conf
ZEPHYR_SDK_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.12.3/zephyr-sdk-0.12.3-x86_64-linux-setup.run"
export ZEPHYR_SDK_INSTALL_DIR="${HOME}/srv/toolchain/zephyr-sdk-0.12.3"

# GNU ARM Embedded is downloaded once (per release) and cached in a persistent
# docker volume under ${HOME}/srv/toolchain/.
GNUARMEMB_TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/9-2019q4/gcc-arm-none-eabi-9-2019-q4-major-x86_64-linux.tar.bz2"
export GNUARMEMB_TOOLCHAIN_PATH="${HOME}/srv/toolchain/gcc-arm-none-eabi-9-2019-q4-major"

install_zephyr_sdk()
{
    test -d ${ZEPHYR_SDK_INSTALL_DIR} && return 0
    test -f ${ZEPHYR_SDK_INSTALL_DIR}.lck && exit 1
    touch ${ZEPHYR_SDK_INSTALL_DIR}.lck
    wget -q "${ZEPHYR_SDK_URL}"
    chmod +x $(basename ${ZEPHYR_SDK_URL})
    ./$(basename ${ZEPHYR_SDK_URL}) --quiet --nox11 -- <<< ${ZEPHYR_SDK_INSTALL_DIR}
    rm -f ${ZEPHYR_SDK_INSTALL_DIR}.lck
}

install_arm_toolchain()
{
    test -d ${GNUARMEMB_TOOLCHAIN_PATH} && return 0
    wget -q "${GNUARMEMB_TOOLCHAIN_URL}"
    top=$(dirname ${GNUARMEMB_TOOLCHAIN_PATH})
    rm -rf ${top}/_tmp.$$
    mkdir -p ${top}/_tmp.$$
    tar -C ${top}/_tmp.$$ -xaf $(basename ${GNUARMEMB_TOOLCHAIN_URL})
    mv ${top}/_tmp.$$/$(basename ${GNUARMEMB_TOOLCHAIN_PATH}) ${top}
}

ls -l ${HOME}/srv/toolchain/
install_zephyr_sdk
install_arm_toolchain
#find ${ZEPHYR_SDK_INSTALL_DIR}
${ZEPHYR_SDK_INSTALL_DIR}/sysroots/x86_64-pokysdk-linux/usr/bin/dtc --version

# Set build environment variables
export LANG=C.UTF-8
ZEPHYR_BASE=${WORKSPACE}/zephyr
PATH=${ZEPHYR_BASE}/scripts:${PATH}
OUTDIR=${HOME}/srv/zephyr/${BRANCH}/${ZEPHYR_TOOLCHAIN_VARIANT}/${PLATFORM}
export LANG ZEPHYR_BASE PATH
CCACHE_DIR="${HOME}/srv/ccache-zephyr/${BRANCH}"
CCACHE_UNIFY=1
CCACHE_SLOPPINESS=file_macro,include_file_mtime,time_macros
USE_CCACHE=1
export CCACHE_DIR CCACHE_UNIFY CCACHE_SLOPPINESS USE_CCACHE
env |grep '^ZEPHYR'
mkdir -p "${CCACHE_DIR}"
rm -rf ${OUTDIR}

echo ""
echo "########################################################################"
echo "    mass-build (twister)"
echo "########################################################################"

time ${ZEPHYR_BASE}/scripts/twister \
  --platform ${PLATFORM} \
  --inline-logs \
  --build-only \
  --outdir ${OUTDIR} \
  --enable-slow \
  -x=USE_CCACHE=${USE_CCACHE} \
  --jobs 2 \
  ${TWISTER_EXTRA}

# Put report where rsync below will pick it up.
cp ${OUTDIR}/twister.csv ${OUTDIR}/${PLATFORM}/

cd ${ZEPHYR_BASE}
# OUTDIR is already per-platform, but it may get contaminated with unrelated
# builds e.g. due to bugs in twister script. It however stores builds in
# per-platform named subdirs under its --outdir (${OUTDIR} in our case), so
# we use ${OUTDIR}/${PLATFORM} paths below.
find ${OUTDIR}/${PLATFORM} -type f -name '.config' -exec rename 's/.config/zephyr.config/' {} +
rsync -avm \
  --include=zephyr.bin \
  --include=zephyr.config \
  --include=zephyr.elf \
  --include='twister.*' \
  --include='*/' \
  --exclude='*' \
  ${OUTDIR}/${PLATFORM} ${WORKSPACE}/out/
find ${OUTDIR}/${PLATFORM} -type f -name 'zephyr.config' -delete
# If there are support files, ship them.
BOARD_CONFIG=$(find "${ZEPHYR_BASE}/boards/" -type f -name "${PLATFORM}_defconfig")
BOARD_DIR=$(dirname ${BOARD_CONFIG})
test -d "${BOARD_DIR}/support" && rsync -avm "${BOARD_DIR}/support" "${WORKSPACE}/out/${PLATFORM}"

cd ${WORKSPACE}/
echo "=== contents of ${WORKSPACE}/out/ ==="
find out
echo "=== end of contents of ${WORKSPACE}/out/ ==="

CCACHE_DIR=${CCACHE_DIR} ccache -M 30G
CCACHE_DIR=${CCACHE_DIR} ccache -s
