#!/bin/bash -e

if [ -z "${WORKSPACE}" ]; then
  # Local build
  export WORKSPACE=${PWD}
fi

echo "#${BUILD_NUMBER}-${ghprbActualCommit:0:8}" > ${WORKSPACE}/version.txt

# Build dependencies already pre-installed on the node
#sudo apt update -q=2
#sudo apt install -q=2 --yes --no-install-recommends zlib1g-dev libnuma-dev

# use UADK master
git clone --depth 1 https://github.com/Linaro/uadk.git ${WORKSPACE}/uadk-master
cd ${WORKSPACE}/uadk-master
autoreconf -vfi

# shared build for v2
./configure \
  --host aarch64-linux-gnu \
  --target aarch64-linux-gnu \
  --prefix=${WORKSPACE}/uadk-shared-v2/usr/local \
  --includedir=${WORKSPACE}/uadk-shared-v2/usr/local/include/uadk \
  --disable-static \
  --enable-shared
make -j$(nproc)
make install && make clean
sudo \
  LD_LIBRARY_PATH=${WORKSPACE}/uadk-shared-v2/usr/local/lib/ \
  PATH=${WORKSPACE}/uadk-shared-v2/usr/local/bin:${PATH}  \
  C_INCLUDE_PATH=${WORKSPACE}/uadk-shared-v2/usr/local/include/ \
  ${WORKSPACE}/uadk-master/test/sanity_test.sh

cd ${WORKSPACE}/uadk
autoreconf -vfi

./configure \
  --prefix=${WORKSPACE}/uadk-shared-v2/usr/local \
  --libdir=${WORKSPACE}/uadk-shared-v2/usr/local/lib
LD_LIBRARY_PATH=${WORKSPACE}/uadk-shared-v2/usr/local/lib make -j$(nproc)
make install && make clean

# FIXME: openssl: symbol lookup error: openssl: undefined symbol: EVP_mdc2, version OPENSSL_1_1_0
# $ which openssl
# $ /usr/local/bin/openssl
# Using the system /usr/bin/openssl returns an error too
#sudo \
#  LD_LIBRARY_PATH=${WORKSPACE}/uadk-shared-v2/usr/local/lib \
#  openssl engine -t uadk

cd ${WORKSPACE}
tar -cJf uadk-openssl.tar.xz uadk-*-v*/
