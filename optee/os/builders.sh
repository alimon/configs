#!/bin/bash

set -e

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="bc ccache git expect pkg-config python-requests python-crypto python-wand wget zlib1g-dev"
pkg_list+=" libglib2.0-dev libpixman-1-dev"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

set -ex

CC=gcc
CCACHE_DIR="${HOME}/srv/ccache"
CCACHE_UNIFY=1
CCACHE_SLOPPINESS=file_macro,include_file_mtime,time_macros
PATH=/usr/lib/ccache:${PATH}
export CC CCACHE_DIR CCACHE_UNIFY CCACHE_SLOPPINESS PATH

# Install the cross compilers
#wget -q \
#  http://releases.linaro.org/components/toolchain/binaries/5.3.1-2016.05/arm-linux-gnueabihf/gcc-linaro-5.3.1-2016.05-x86_64_arm-linux-gnueabihf.tar.xz
#  http://releases.linaro.org/components/toolchain/binaries/5.3.1-2016.05/aarch64-linux-gnu/gcc-linaro-5.3.1-2016.05-x86_64_aarch64-linux-gnu.tar.xz
#tar xf gcc-linaro-5.3.1-2016.05-x86_64_*.tar.xz
export PATH="${HOME}/srv/toolchain/gcc-linaro-5.3.1-2016.05-x86_64_aarch64-linux-gnu/bin:${HOME}/srv/toolchain/gcc-linaro-5.3.1-2016.05-x86_64_arm-linux-gnueabihf/bin:${PATH}"
which arm-linux-gnueabihf-gcc && arm-linux-gnueabihf-gcc --version
which aarch64-linux-gnu-gcc && aarch64-linux-gnu-gcc --version

# Store the home repository
if [ -z "${WORKSPACE}" ]; then
  # Local build
  export WORKSPACE=${PWD}
fi

# Download checkpatch.pl
export DST_KERNEL=${WORKSPACE}/linux && mkdir -p ${DST_KERNEL}/scripts && cd ${DST_KERNEL}/scripts
wget -q https://raw.githubusercontent.com/torvalds/linux/master/scripts/checkpatch.pl -O checkpatch.pl && chmod a+x checkpatch.pl
wget -q https://raw.githubusercontent.com/torvalds/linux/master/scripts/spelling.txt -O spelling.txt
echo "invalid.struct.name" > const_structs.checkpatch
cd ${WORKSPACE}

export make="make -j$(nproc) -s"

# Tools required for QEMU tests
mkdir -p ${HOME}/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo && chmod a+x ${HOME}/bin/repo
export PATH=${HOME}/bin:${PATH}
mkdir ${HOME}/optee_repo
(cd ${HOME}/optee_repo && repo init -u https://github.com/OP-TEE/manifest.git -m travis.xml </dev/null && repo sync --no-clone-bundle --no-tags --quiet -j$(nproc))
(cd ${HOME}/optee_repo/qemu && git submodule update --init dtc)
(cd ${HOME}/optee_repo && mv optee_os optee_os_old && ln -s ${WORKSPACE} optee_os)
cd ${WORKSPACE}
git fetch https://github.com/OP-TEE/optee_os --tags
unset CC

export PATH=${DST_KERNEL}/scripts/:${PATH}
source ${HOME}/optee_repo/optee_os/scripts/checkpatch_inc.sh

# Several compilation options are checked
if [ "${COVERITY_SCAN_BRANCH}" == "1" ]; then
  echo "Skip script for Coverity"
  #travis_terminate 0
fi

# Run checkpatch.pl on:
# * the tip of the branch if we're not in a pull request
# * each commit in the development branch that's not in the target branch otherwise
if [ "${TRAVIS_PULL_REQUEST}" == "false" ]; then
  checkpatch HEAD
else
  for c in $(git rev-list HEAD^1..HEAD^2); do
    checkpatch ${c} || failed=1
  done
  [ -z "${failed}" ]
fi
# If we have a pull request with more than 1 commit, also check the squashed commits
# Useful to check if fix-up commits do indeed solve previous checkpatch errors
if [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
  if [ $(git rev-list --count HEAD^1..HEAD^2) -gt 1 ]; then
    checkdiff $(git rev-parse HEAD^1) $(git rev-parse HEAD^2)
  fi
fi

# b2260
${make} PLATFORM=stm-b2260
${make} PLATFORM=stm-b2260 CFG_TEE_CORE_LOG_LEVEL=4 DEBUG=1
${make} PLATFORM=stm-b2260 CFG_TEE_CORE_LOG_LEVEL=0 CFG_TEE_TA_LOG_LEVEL=0 DEBUG=0

# Cannes
${make} PLATFORM=stm-cannes
${make} PLATFORM=stm-cannes CFG_TEE_CORE_LOG_LEVEL=4 DEBUG=1
${make} PLATFORM=stm-cannes CFG_TEE_CORE_LOG_LEVEL=0 CFG_TEE_TA_LOG_LEVEL=0 DEBUG=0

# FVP
${make} PLATFORM=vexpress-fvp CFG_ARM32_core=y
${make} PLATFORM=vexpress-fvp CFG_TEE_CORE_LOG_LEVEL=4 DEBUG=1 CFG_TZC400=y
${make} PLATFORM=vexpress-fvp CFG_TEE_CORE_LOG_LEVEL=0 CFG_TEE_TA_LOG_LEVEL=0 DEBUG=0 CFG_TZC400=y
${make} PLATFORM=vexpress-fvp CFG_ARM64_core=y
${make} PLATFORM=vexpress-fvp CFG_ARM64_core=y CFG_TEE_CORE_LOG_LEVEL=4 DEBUG=1 CFG_TZC400=y
${make} PLATFORM=vexpress-fvp CFG_ARM64_core=y CFG_TEE_CORE_LOG_LEVEL=0 CFG_TEE_TA_LOG_LEVEL=0 DEBUG=0 CFG_TZC400=y

# Juno
${make} PLATFORM=vexpress-juno
${make} PLATFORM=vexpress-juno CFG_TEE_CORE_LOG_LEVEL=4 DEBUG=1
${make} PLATFORM=vexpress-juno CFG_TEE_CORE_LOG_LEVEL=0 CFG_TEE_TA_LOG_LEVEL=0 DEBUG=0
${make} PLATFORM=vexpress-juno CFG_ARM64_core=y
${make} PLATFORM=vexpress-juno CFG_ARM64_core=y CFG_TEE_CORE_LOG_LEVEL=4 DEBUG=1
${make} PLATFORM=vexpress-juno CFG_ARM64_core=y CFG_TEE_CORE_LOG_LEVEL=0 CFG_TEE_TA_LOG_LEVEL=0 DEBUG=0

# QEMU-virt (PLATFORM=vexpress-qemu_virt)
${make}
${make} CFG_TEE_CORE_LOG_LEVEL=4 DEBUG=1
${make} CFG_TEE_CORE_LOG_LEVEL=3 DEBUG=1
${make} CFG_TEE_CORE_LOG_LEVEL=2 DEBUG=1
${make} CFG_TEE_CORE_LOG_LEVEL=1 CFG_TEE_CORE_DEBUG=y DEBUG=1
${make} CFG_TEE_CORE_LOG_LEVEL=1 CFG_TEE_CORE_DEBUG=n DEBUG=0
${make} CFG_TEE_CORE_LOG_LEVEL=0 CFG_TEE_CORE_DEBUG=y DEBUG=1
${make} CFG_TEE_CORE_LOG_LEVEL=0 CFG_TEE_CORE_DEBUG=n DEBUG=0
${make} CFG_TEE_CORE_LOG_LEVEL=0 CFG_TEE_CORE_DEBUG=n CFG_TEE_TA_LOG_LEVEL=0 DEBUG=0
${make} CFG_TEE_CORE_MALLOC_DEBUG=y
${make} CFG_CORE_SANITIZE_UNDEFINED=y
${make} CFG_CORE_SANITIZE_KADDRESS=y
${make} CFG_CRYPTO=n
${make} CFG_CRYPTO_{AES,DES}=n
${make} CFG_CRYPTO_{DSA,RSA,DH}=n
${make} CFG_CRYPTO_{DSA,RSA,DH,ECC}=n
${make} CFG_CRYPTO_{H,C,CBC_}MAC=n
${make} CFG_CRYPTO_{G,C}CM=n
${make} CFG_CRYPTO_{MD5,SHA{1,224,256,384,512}}=n
${make} CFG_CRYPTO=n CFG_CRYPTO_ECC=y
${make} CFG_WITH_PAGER=y
${make} CFG_WITH_PAGER=y CFG_TEE_CORE_DEBUG=y
${make} CFG_WITH_PAGER=y CFG_WITH_LPAE=y
${make} CFG_WITH_LPAE=y
${make} CFG_WITH_STATS=y
${make} CFG_RPMB_FS=y
${make} CFG_RPMB_FS=y CFG_RPMB_TESTKEY=y
${make} CFG_REE_FS=n CFG_RPMB_FS=y
${make} CFG_WITH_USER_TA=n CFG_CRYPTO=n CFG_SE_API=n CFG_PCSC_PASSTHRU_READER_DRV=n
${make} CFG_SMALL_PAGE_USER_TA=n
${make} CFG_SQL_FS=y
${make} CFG_WITH_PAGER=y CFG_WITH_LPAE=y CFG_RPMB_FS=y CFG_SQL_FS=y CFG_DT=y CFG_PS2MOUSE=y CFG_PL050=y CFG_PL111=y CFG_TEE_CORE_LOG_LEVEL=1 CFG_TEE_CORE_DEBUG=y DEBUG=1
${make} CFG_WITH_PAGER=y CFG_WITH_LPAE=y CFG_RPMB_FS=y CFG_SQL_FS=y CFG_DT=y CFG_PS2MOUSE=y CFG_PL050=y CFG_PL111=y CFG_TEE_CORE_LOG_LEVEL=0 CFG_TEE_CORE_DEBUG=n DEBUG=0
${make} CFG_BUILT_IN_ARGS=y CFG_PAGEABLE_ADDR=0 CFG_NS_ENTRY_ADDR=0 CFG_DT_ADDR=0 CFG_DT=y
${make} CFG_TA_GPROF_SUPPORT=y CFG_ULIBS_GPROF=y
${make} CFG_SECURE_DATA_PATH=y

# QEMU-ARMv8A
${make} PLATFORM=vexpress-qemu_armv8a CFG_ARM64_core=y
${make} PLATFORM=vexpress-qemu_armv8a CFG_ARM64_core=y CFG_RPMB_FS=y CFG_SQL_FS=y
${make} PLATFORM=vexpress-qemu_armv8a CFG_ARM64_core=y CFG_TA_GPROF_SUPPORT=y CFG_ULIBS_GPROF=y

# SUNXI(Allwinner A80)
${make} PLATFORM=sunxi CFG_TEE_CORE_LOG_LEVEL=4 DEBUG=1
${make} PLATFORM=sunxi CFG_TEE_CORE_LOG_LEVEL=0 CFG_TEE_TA_LOG_LEVEL=0 DEBUG=0

# HiKey board (HiSilicon Kirin 620)
${make} PLATFORM=hikey
${make} PLATFORM=hikey CFG_ARM64_core=y
${make} PLATFORM=hikey CFG_ARM64_core=y CFG_TEE_TA_LOG_LEVEL=4 DEBUG=1

# Mediatek mt8173 EVB
${make} PLATFORM=mediatek-mt8173 CFG_ARM64_core=y

# i.MX6UL 14X14 EVK
${make} PLATFORM=imx-mx6ulevk ARCH=arm CFG_PAGEABLE_ADDR=0 CFG_NS_ENTRY_ADDR=0x80800000 CFG_DT_ADDR=0x83000000 CFG_DT=y DEBUG=y CFG_TEE_CORE_LOG_LEVEL=4

# i.MX6Quad SABRE
${make} PLATFORM=imx-mx6qsabrelite
${make} PLATFORM=imx-mx6qsabresd
${make} PLATFORM=imx-mx6dlsabresd

# Texas Instruments DRA7xx
${make} PLATFORM=ti-dra7xx

# Texas Instruments AM57xx
${make} PLATFORM=ti-am57xx

# Texas Instruments AM43xx
${make} PLATFORM=ti-am43xx

# Spreadtrum sc9860
${make} PLATFORM=sprd-sc9860
${make} PLATFORM=sprd-sc9860 CFG_ARM64_core=y

# FSL ls1021a
${make} PLATFORM=ls-ls1021atwr
${make} PLATFORM=ls-ls1021aqds

# Xilinx Zynq7000 ZC702
${make} PLATFORM=zynq7k-zc702

# Xilinx ZynqMP
${make} PLATFORM=zynqmp-zcu102
${make} PLATFORM=zynqmp-zcu102 CFG_ARM64_core=y

# HiSilicon D02
${make} PLATFORM=d02
${make} PLATFORM=d02 CFG_ARM64_core=y

# Renesas RCAR H3
${make} PLATFORM=rcar
${make} PLATFORM=rcar CFG_ARM64_core=y

# Raspberry Pi 3
${make} PLATFORM=rpi3
${make} PLATFORM=rpi3 CFG_ARM64_core=y

# Run regression tests (xtest in QEMU)
(cd ${HOME}/optee_repo/build && ${make} check CROSS_COMPILE="ccache arm-linux-gnueabihf-" AARCH32_CROSS_COMPILE=arm-linux-gnueabihf- CFG_TEE_CORE_DEBUG=y DUMP_LOGS_ON_ERROR=1)
