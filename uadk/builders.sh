#!/bin/bash -e

if [ -z "${WORKSPACE}" ]; then
  # Local build
  export WORKSPACE=${PWD}
fi

echo "#${BUILD_NUMBER}-${ghprbActualCommit:0:8}" > ${WORKSPACE}/version.txt

# Build dependencies already pre-installed on the node
#sudo apt update -q=2
#sudo apt install -q=2 --yes --no-install-recommends zlib1g-dev libnuma-dev

cd ${WORKSPACE}/uadk
autoreconf -vfi

# shared build for v1
./conf.sh --with-uadk_v1 && make -j$(nproc)
make install DESTDIR=${WORKSPACE}/uadk-shared-v1 && make clean
sudo \
  LD_LIBRARY_PATH=${WORKSPACE}/uadk-shared-v1/usr/local/lib/ \
  PATH=${WORKSPACE}/uadk-shared-v1/usr/local/bin:${PATH}  \
  C_INCLUDE_PATH=${WORKSPACE}/uadk-shared-v1/usr/local/include/ \
  ${WORKSPACE}/uadk/test/sanity_test.sh

# shared build for v2
./conf.sh && make -j$(nproc)
make install DESTDIR=${WORKSPACE}/uadk-shared-v2 && make clean
sudo \
  LD_LIBRARY_PATH=${WORKSPACE}/uadk-shared-v2/usr/local/lib/ \
  PATH=${WORKSPACE}/uadk-shared-v2/usr/local/bin:${PATH}  \
  C_INCLUDE_PATH=${WORKSPACE}/uadk-shared-v2/usr/local/include/ \
  ${WORKSPACE}/uadk/test/sanity_test.sh

# static build for v1
./conf.sh --with-uadk_v1 --static && make -j$(nproc)
make install DESTDIR=${WORKSPACE}/uadk-static-v1 && make clean
sudo \
  LD_LIBRARY_PATH=${WORKSPACE}/uadk-static-v1/usr/local/lib/ \
  PATH=${WORKSPACE}/uadk-static-v1/usr/local/bin:${PATH}  \
  C_INCLUDE_PATH=${WORKSPACE}/uadk-static-v1/usr/local/include/ \
  ${WORKSPACE}/uadk/test/sanity_test.sh

# static build for v2
./conf.sh --static && make -j$(nproc)
make install DESTDIR=${WORKSPACE}/uadk-static-v2 && make clean
sudo \
  LD_LIBRARY_PATH=${WORKSPACE}/uadk-static-v2/usr/local/lib/ \
  PATH=${WORKSPACE}/uadk-static-v2/usr/local/bin:${PATH}  \
  C_INCLUDE_PATH=${WORKSPACE}/uadk-static-v2/usr/local/include/ \
  ${WORKSPACE}/uadk/test/sanity_test.sh

cd ${WORKSPACE}
tar -cJf uadk.tar.xz uadk-*-v*/
