#!/bin/bash
set -ex

export PATH=$PATH://home/buildslave/bin/

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

# Toolchain src downloads
if [ -d llvm ]; then
    rm llvm -rf
fi
repo init -u https://android-git.linaro.org/git/platform/manifest.git -b clang-build
repo sync -j16 -c

# For building LLVMgold.so using -DLLVM_BINUTILS_INCDIR flag
if [ ! -d binutils ]; then
    git clone https://android.googlesource.com/toolchain/binutils
else
    cd binutils
    git pull
    cd ..
fi

# Toolchain download
if [ ! -d clang+llvm-5.0.0-linux-x86_64-ubuntu14.04 ]; then
    wget http://releases.llvm.org/5.0.0/clang+llvm-5.0.0-linux-x86_64-ubuntu14.04.tar.xz
    tar xvfJ clang+llvm-5.0.0-linux-x86_64-ubuntu14.04.tar.xz
fi

# Temporary clang patch for 25b45aa81854313486df891985cdd7ef1ec09780
# cd ${HOME}/srv/aosp/${JOB_NAME}/llvm/tools/clang
# git clone https://git.linaro.org/people/minseong.kim/aosp_patches_for_upstream_clang.git
# patch -p1 < aosp_patches_for_upstream_clang/revert_25b45a.patch
# cd ${HOME}/srv/aosp/${JOB_NAME}

cd llvm
mkdir -p build/clang-master
cd build
cmake -G "Unix Makefiles" ../ \
	 -DCMAKE_BUILD_TYPE=Release \
	 -DPYTHON_EXECUTABLE=/usr/bin/python2 \
	 -DCMAKE_INSTALL_PREFIX=./clang-master \
	 -DLLVM_TARGETS_TO_BUILD="host;ARM;X86;AArch64" \
	 -DLLVM_ENABLE_ASSERTIONS=false \
	 -DCMAKE_C_COMPILER=${HOME}/srv/aosp/${JOB_NAME}/clang+llvm-5.0.0-linux-x86_64-ubuntu14.04/bin/clang \
	 -DCMAKE_CXX_COMPILER=${HOME}/srv/aosp/${JOB_NAME}/clang+llvm-5.0.0-linux-x86_64-ubuntu14.04/bin/clang++ \
	 -DLIBCXXABI_LIBCXX_INCLUDES=${HOME}/srv/aosp/${JOB_NAME}/llvm/projects/libcxx/include \
	 -DLIBCXX_CXX_ABI_INCLUDE_PATHS=${HOME}/srv/aosp/${JOB_NAME}/llvm/projects/libcxxabi/include \
	 -DLLVM_BINUTILS_INCDIR=${HOME}/srv/aosp/${JOB_NAME}/binutils/binutils-2.27/include

make install VERBOSE=1 -j"$(nproc)"

rm -f clang-master.tar.xz
tar -I pxz -cf clang-master.tar.xz clang-master

echo "Build finished"
