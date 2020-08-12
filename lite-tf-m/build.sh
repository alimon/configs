#!/bin/bash
set -ex

# We don't build anything so far, just downloading pre-built.
wget https://people.linaro.org/~kevin.townsend/lava/an521_tfm_full.hex -O tfm_full.hex

#echo "GIT_COMMIT_ID=$(git rev-parse --short=8 HEAD)" > ${WORKSPACE}/env_var_parameters
#echo "EXTERNAL_BUILD_ID=$(git rev-parse --short=8 HEAD)-${BUILD_NUMBER}" >> ${WORKSPACE}/env_var_parameters

echo "GIT_COMMIT_ID=unk" > ${WORKSPACE}/env_var_parameters
echo "EXTERNAL_BUILD_ID=unk-${BUILD_NUMBER}" >> ${WORKSPACE}/env_var_parameters
