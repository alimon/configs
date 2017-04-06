#!/bin/bash

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi

pkg_list="git libcap-dev libcap-ng-dev libfuse-dev libmount-dev libpopt-dev pkg-config pxz rsync"
deb_host_arch=$(dpkg-architecture -qDEB_HOST_ARCH)
[ "deb_host_arch" != "armhf" ] &&  pkg_list+=" libnuma-dev"

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

set -x

make headers_install
export INSTALL_PATH=kselftest
make -C tools/testing/selftests
make -C tools/testing/selftests install

mkdir -p tools/testing/selftests/out
cd tools/testing/selftests
tar -I pxz -cf ../out/kselftest_${deb_host_arch}_$(git describe).tar.xz kselftest
