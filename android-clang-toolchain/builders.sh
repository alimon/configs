#!/bin/bash
set -ex

export PATH=$PATH://home/buildslave/bin/

sudo apt-get -q=2 update
sudo apt-get -q=2 install -y libxml2-dev zlib1g-dev libtinfo-dev git-svn gawk libxml2-utils rsync pxz python-requests ninja-build

wget -q \
  https://cmake.org/files/v3.11/cmake-3.11.0-Linux-x86_64.sh

yes y | bash cmake-3.11.0-Linux-x86_64.sh
export PATH=${PWD}/cmake-3.11.0-Linux-x86_64/bin/:${PATH}

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
if [ ! -d clang+llvm-6.0.0-x86_64-linux-gnu-ubuntu-14.04 ]; then
    wget http://releases.llvm.org/6.0.0/clang+llvm-6.0.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz
    tar xvfJ clang+llvm-6.0.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz
fi

# Temporary clang patch for 25b45aa81854313486df891985cdd7ef1ec09780
# cd ${HOME}/srv/aosp/${JOB_NAME}/llvm/tools/clang
# git clone https://git.linaro.org/people/minseong.kim/aosp_patches_for_upstream_clang.git
# patch -p1 < aosp_patches_for_upstream_clang/revert_25b45a.patch
# cd ${HOME}/srv/aosp/${JOB_NAME}

cd llvm
mkdir -p build/clang-master
cd build
cmake -G Ninja ../ \
	 -DCMAKE_BUILD_TYPE=Release \
	 -DPYTHON_EXECUTABLE=/usr/bin/python2 \
	 -DCMAKE_INSTALL_PREFIX=./clang-master \
	 -DLLVM_TARGETS_TO_BUILD="host;ARM;X86;AArch64" \
	 -DLLVM_ENABLE_ASSERTIONS=false \
	 -DCMAKE_C_COMPILER=${HOME}/srv/aosp/${JOB_NAME}/clang+llvm-6.0.0-x86_64-linux-gnu-ubuntu-14.04/bin/clang \
	 -DCMAKE_CXX_COMPILER=${HOME}/srv/aosp/${JOB_NAME}/clang+llvm-6.0.0-x86_64-linux-gnu-ubuntu-14.04/bin/clang++ \
	 -DLIBCXXABI_LIBCXX_INCLUDES=${HOME}/srv/aosp/${JOB_NAME}/llvm/projects/libcxx/include \
	 -DLIBCXX_CXX_ABI_INCLUDE_PATHS=${HOME}/srv/aosp/${JOB_NAME}/llvm/projects/libcxxabi/include \
	 -DLLVM_BINUTILS_INCDIR=${HOME}/srv/aosp/${JOB_NAME}/binutils/binutils-2.27/include \
	 -DLLVM_LIBDIR_SUFFIX=64 \
	 -DCLANG_LIBDIR_SUFFIX=64

VERBOSE=1 ninja install
mkdir -p clang-master/prebuilt_include/llvm/lib/Fuzzer
cp -a ../projects/compiler-rt/lib/fuzzer/*.{h,def} clang-master/prebuilt_include/llvm/lib/Fuzzer/

rm -f clang-master.tar.xz
tar -I pxz -cf clang-master.tar.xz clang-master

echo "Build finished"
