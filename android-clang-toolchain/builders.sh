#!/bin/bash

sudo apt-get -q=2 update
sudo apt-get -q=2 install -y libxml2-dev zlib1g-dev libtinfo-dev git-svn gawk libxml2-utils rsync pxz python-requests

wget -q \
  http://archive.ubuntu.com/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jre-headless_8u45-b14-1_amd64.deb \
  http://archive.ubuntu.com/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jre_8u45-b14-1_amd64.deb \
  http://archive.ubuntu.com/ubuntu/pool/universe/o/openjdk-8/openjdk-8-jdk_8u45-b14-1_amd64.deb \
  https://cmake.org/files/v3.5/cmake-3.5.2-Linux-x86_64.sh
sudo dpkg -i --force-all *.deb
rm -f *.deb

yes y | bash cmake-3.5.2-Linux-x86_64.sh
export PATH=${PWD}/cmake-3.5.2-Linux-x86_64/bin/:${PATH}

mkdir -p ${HOME}/srv/aosp/${JOB_NAME}
cd ${HOME}/srv/aosp/${JOB_NAME}

repo init -u https://android-git.linaro.org/git/platform/manifest.git -b clang-build
repo sync -j16 -c

# For building LLVMgold.so using -DLLVM_BINUTILS_INCDIR flag
git clone https://android.googlesource.com/toolchain/binutils

cd llvm
mkdir -p build/clang-master
cd build
cmake -G "Unix Makefiles" ../ \
 -DCMAKE_BUILD_TYPE=Release \
 -DPYTHON_EXECUTABLE=/usr/bin/python2 \
 -DCMAKE_INSTALL_PREFIX=./clang-master \
 -DLLVM_TARGETS_TO_BUILD="ARM;X86;AArch64" \
 -DLLVM_ENABLE_ASSERTIONS=false \
 -DLLVM_BINUTILS_INCDIR=${HOME}/srv/aosp/${JOB_NAME}/binutils/binutils-2.27/include \
make install -j"$(nproc)"

rm -f clang-master.tar.xz
tar -I pxz -cf clang-master.tar.xz clang-master

echo "Build finished"
