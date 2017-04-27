#!/bin/bash

set -e

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="python-requests"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

set -ex

# Install the cross compiler
#wget -q http://releases.linaro.org/components/toolchain/binaries/5.3.1-2016.05/arm-linux-gnueabihf/gcc-linaro-5.3.1-2016.05-x86_64_arm-linux-gnueabihf.tar.xz
#tar xf gcc-linaro-5.3.1-2016.05-x86_64_*.tar.xz
export PATH="${HOME}/srv/toolchain/gcc-linaro-5.3.1-2016.05-x86_64_arm-linux-gnueabihf/bin:${PATH}"
which arm-linux-gnueabihf-gcc && arm-linux-gnueabihf-gcc --version

# Several compilation options are checked
# Explicitely disable parallel make because it's broken
export make="make -j1"
${make} clean all
CFG_TEE_CLIENT_LOG_LEVEL=0 ${make} clean all
CFG_TEE_CLIENT_LOG_LEVEL=5 ${make} clean all
CFG_SQL_FS=y ${make} clean all
