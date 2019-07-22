#!/bin/bash

set -ex

sudo apt -q=2 update
sudo apt -q=2 install -y --no-install-recommends build-essential scons cmake git autoconf curl libtool libpthread-stubs0-dev

git clone --depth 1 https://github.com/Arm-software/ComputeLibrary.git
git clone https://github.com/Arm-software/armnn
git clone --depth 1 -b v3.5.0 https://github.com/google/protobuf.git
git clone --depth 1 https://github.com/tensorflow/tensorflow.git
git clone --depth 1 https://github.com/google/flatbuffers.git
wget -q https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.bz2 && tar xf boost_*.tar.bz2

if [ -n "$GERRIT_PROJECT" ] && [ $GERRIT_EVENT_TYPE == "patchset-created" ]; then
    cd armnn
    GERRIT_URL="http://${GERRIT_HOST}/${GERRIT_PROJECT}"
    if git pull ${GERRIT_URL} ${GERRIT_REFSPEC} | grep -q "Automatic merge failed"; then
        git reset --hard
        echo "Error: *** Error patch merge failed"
        exit 1
    fi
fi

cd ${WORKSPACE}/ComputeLibrary
#need to add if loops for opencl=1 embed_kernels=1 and neon=1
scons -u -j$(nproc) arch=arm64-v8a extra_cxx_flags="-fPIC" benchmark_tests=1 validation_tests=1

#build Boost
cd ${WORKSPACE}/boost_1_64_0
./bootstrap.sh
./b2  \
  --build-dir=${WORKSPACE}/boost_1_64_0/build toolset=gcc link=static cxxflags=-fPIC \
  --with-filesystem \
  --with-test \
  --with-log \
  --with-program_options install --prefix=${WORKSPACE}/boost

#build Protobuf
cd ${WORKSPACE}/protobuf
git submodule update --init --recursive
./autogen.sh
./configure --prefix=${WORKSPACE}/protobuf-host
make -j$(nproc)
make install

#generate tensorflow protobuf library
cd ${WORKSPACE}/tensorflow
${WORKSPACE}/armnn/scripts/generate_tensorflow_protobuf.sh \
  ${WORKSPACE}/tensorflow-protobuf \
  ${WORKSPACE}/protobuf-host

#build google flatbuffer libraries
cd ${WORKSPACE}/flatbuffers
cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

#Build Arm NN
cd ${WORKSPACE}/armnn
mkdir build
cd build
cmake .. \
  -DARMCOMPUTE_ROOT=${WORKSPACE}/ComputeLibrary \
  -DARMCOMPUTE_BUILD_DIR=${WORKSPACE}/ComputeLibrary/build \
  -DBOOST_ROOT=${WORKSPACE}/boost \
  -DTF_GENERATED_SOURCES=${WORKSPACE}/tensorflow-protobuf \
  -DBUILD_TF_PARSER=1 \
  -DPROTOBUF_ROOT=${WORKSPACE}/protobuf-host \
  -DBUILD_TF_LITE_PARSER=1 \
  -DTF_LITE_GENERATED_PATH=${WORKSPACE}/tensorflow/tensorflow/lite/schema \
  -DFLATBUFFERS_ROOT=${WORKSPACE}/flatbuffers \
  -DFLATBUFFERS_LIBRARY=${WORKSPACE}/flatbuffers/libflatbuffers.a
make -j$(nproc)

cd ${WORKSPACE}
rm -rf boost_*.tar.bz2 boost_* protobuf tensorflow
find ${WORKSPACE} -type f -name *.o -delete

tar -cJf /tmp/armnn.tar.xz ${WORKSPACE}
mkdir ${WORKSPACE}/out
mv /tmp/armnn.tar.xz ${WORKSPACE}/out
cd ${WORKSPACE}/out && sha256sum > SHA256SUMS.txt
