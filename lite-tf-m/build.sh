#!/bin/bash
set -ex

dir=$(dirname $(readlink -f $0))

# We don't build anything so far, just downloading pre-built.
#wget https://people.linaro.org/~kevin.townsend/lava/an521_tfm_full.hex -O tfm_full.hex

#TOOLCHAINS=${HOME}/srv/toolchain
TOOLCHAINS=${WORKSPACE}/srv/toolchain

GNUARMEMB_TOOLCHAIN_PATH="${TOOLCHAINS}/gcc-arm-none-eabi-9-2019-q4-major"
export PATH=${GNUARMEMB_TOOLCHAIN_PATH}/bin:$PATH

git clone https://git.trustedfirmware.org/trusted-firmware-m.git -b ${BRANCH}
(cd trusted-firmware-m; git checkout ${GIT_COMMIT})
git clone --depth 1 https://github.com/ARMmbed/mbed-crypto.git -b mbedcrypto-3.0.1
git clone --depth 1 https://github.com/ARM-software/CMSIS_5.git -b 5.5.0

cd trusted-firmware-m
echo "GIT_COMMIT_ID=$(git rev-parse --short=8 HEAD)" > ${WORKSPACE}/env_var_parameters
echo "EXTERNAL_BUILD_ID=$(git rev-parse --short=8 HEAD)-${BUILD_NUMBER}" >> ${WORKSPACE}/env_var_parameters

arm-none-eabi-gcc --version

mkdir BUILD
cp ${dir}/tfm-build.sh BUILD/
cd BUILD
./tfm-build.sh

mkdir -p ${WORKSPACE}/out/
cp *.hex ${WORKSPACE}/out/
