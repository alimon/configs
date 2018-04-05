#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
  cd ${WORKSPACE}
  rm -rf build/tmp/
}

# sbin isn't in the PATH by default and prevent to find parted
export PATH="/usr/sbin:/sbin:$PATH"

# Build
source oe-init-build-env
echo "BBLAYERS += \" ${WORKSPACE}/meta-oe\"" >> conf/bblayers.conf
echo "BBLAYERS += \" ${WORKSPACE}/meta-luv\"" >> conf/bblayers.conf
bitbake luv-live-image

rm -f ${WORKSPACE}/build/tmp/deploy/images/qemuarm64/*.txt
find ${WORKSPACE}/build/tmp/deploy/images/qemuarm64 -type l -delete

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --api_version 3 \
  --link-latest \
  ${WORKSPACE}/build/tmp/deploy/images/qemuarm64 openembedded/pre-built/luvos/${BRANCH}/${BUILD_NUMBER}
