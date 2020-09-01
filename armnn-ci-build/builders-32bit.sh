#!/bin/bash

set -ex

sudo apt -q=2 update
sudo apt-get -q=2  install -y  --no-install-recommends git
sudo apt-get -q=2  install -y  --no-install-recommends scons
sudo apt-get -q=2  install -y  --no-install-recommends gcc-arm-linux-gnueabihf
sudo apt-get -q=2  install -y  --no-install-recommends g++-arm-linux-gnueabihf
sudo apt-get -q=2  install -y  --no-install-recommends curl
sudo apt-get -q=2  install -y  --no-install-recommends autoconf
sudo apt-get -q=2  install -y  --no-install-recommends libtool
sudo apt-get -q=2  install -y  --no-install-recommends cmake
sudo apt -q=2 install -y --no-install-recommends build-essential cmake libpthread-stubs0-dev
sudo apt -q=2 install -y --no-install-recommends python-pip python3-pip virtualenv python-dev python3-dev xxd

# Set local configuration
git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"

git clone --depth 1 "http://review.mlplatform.org/ml/ComputeLibrary"
git clone https://github.com/Arm-software/armnn
wget https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.bz2 && tar xf boost_1_64_0.tar.bz2
git clone --depth 1 -b v3.5.0 https://github.com/google/protobuf.git
git clone --depth 1 https://github.com/tensorflow/tensorflow.git --branch r2.0 --single-branch

wget -O flatbuffers-1.10.0.tar.gz https://github.com/google/flatbuffers/archive/v1.10.0.tar.gz && tar xf flatbuffers-1.10.0.tar.gz


if [ -n "$GERRIT_PROJECT" ] && [ $GERRIT_EVENT_TYPE == "patchset-created" ]; then
    cd armnn
    GERRIT_URL="http://${GERRIT_HOST}/${GERRIT_PROJECT}"
    if git pull ${GERRIT_URL} ${GERRIT_REFSPEC} | grep -q "Automatic merge failed"; then
	git reset --hard
        echo "Retrying to apply the patch with: git fetch && git checkout."
        if ! { git fetch ${GERRIT_URL} ${GERRIT_REFSPEC} | git checkout FETCH_HEAD; }; then
            git reset --hard
            echo "Error: *** Error patch merge failed"
            exit 1
        fi
    fi
fi


cd ${WORKSPACE}/ComputeLibrary
scons extra_cxx_flags="-fPIC" Werror=0 debug=0 asserts=0 neon=1 opencl=0 os=linux arch=armv7a examples=1


cd ${WORKSPACE}/boost_1_64_0
./bootstrap.sh
rm project-config.jam || true
wget --no-check-certificate http://people.linaro.org/~theodore.grey/project-config.jam
./b2  \
  --build-dir=${WORKSPACE}/boost_1_64_0/build toolset=gcc link=static cxxflags=-fPIC \
  --with-filesystem \
  --with-test \
  --with-log \
  --with-program_options install --prefix=${WORKSPACE}/boost


cd $WORKSPACE/protobuf
git submodule update --init --recursive
./autogen.sh
./configure --prefix=$WORKSPACE/protobuf-host
make  -j$(nproc)
make install
make clean

./autogen.sh
./configure --prefix=$WORKSPACE/protobuf-arm32 --host=arm-linux CC=arm-linux-gnueabihf-gcc CXX=arm-linux-gnueabihf-g++ --with-protoc=$WORKSPACE/protobuf-host/bin/protoc
make -j$(nproc)
make install


cd $WORKSPACE/tensorflow
../armnn/scripts/generate_tensorflow_protobuf.sh ../tensorflow-protobuf ../protobuf-host

cd $WORKSPACE/flatbuffers-1.10.0
mkdir build && cd build
cmake .. \
-DFLATBUFFERS_BUILD_FLATC=1 \
-DCMAKE_INSTALL_PREFIX:PATH=$WORKSPACE/flatbuffers
make all install

cd $WORKSPACE/flatbuffers-1.10.0
mkdir build-arm32 && cd build-arm32
cmake .. -DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc \
-DCMAKE_CXX_COMPILER=arm-linux-gnueabihf-g++ \
-DFLATBUFFERS_BUILD_FLATC=1 \
-DCMAKE_INSTALL_PREFIX:PATH=$WORKSPACE/flatbuffers-arm32 \
-DFLATBUFFERS_BUILD_TESTS=0
make all install

cd $WORKSPACE
mkdir tflite
cd tflite
cp $WORKSPACE/tensorflow/tensorflow/lite/schema/schema.fbs .       
$WORKSPACE/flatbuffers-1.10.0/build/flatc -c --gen-object-api --reflect-types --reflect-names schema.fbs

cd $WORKSPACE/armnn
mkdir build
cd build

cmake .. -DCMAKE_LINKER=/usr/bin/arm-linux-gnueabihf-ld \
-DCMAKE_C_COMPILER=/usr/bin/arm-linux-gnueabihf-gcc \
-DCMAKE_CXX_COMPILER=/usr/bin/arm-linux-gnueabihf-g++ \
-DCMAKE_C_COMPILER_FLAGS=-fPIC \
-DCMAKE_CXX_FLAGS=-mfpu=neon \
-DARMCOMPUTE_ROOT=$WORKSPACE/ComputeLibrary \
-DARMCOMPUTE_BUILD_DIR=$WORKSPACE/ComputeLibrary/build \
-DBOOST_ROOT=$WORKSPACE/boost \
-DTF_GENERATED_SOURCES=$WORKSPACE/tensorflow-protobuf \
-DBUILD_TF_PARSER=1 \
-DBUILD_TF_LITE_PARSER=1 \
-DTF_LITE_GENERATED_PATH=$WORKSPACE/tflite \
-DFLATBUFFERS_ROOT=$WORKSPACE/flatbuffers-arm32 \
-DFLATC_DIR=$WORKSPACE/flatbuffers-1.10.0/build \
-DPROTOBUF_ROOT=$WORKSPACE/protobuf-arm32 \
-DARMCOMPUTENEON=1 \
-DARMNNREF=1
make -j$(nproc)

cd ${WORKSPACE}
rm -rf boost_*.tar.bz2 boost_* protobuf tensorflow
find ${WORKSPACE} -type f -name *.o -delete
tar -cJf /tmp/armnn-full-32.tar.xz ${WORKSPACE}

mv armnn/build .
mv protobuf-arm32/lib/libprotobuf.so.15.0.0 build
rm -rf boost armnn ComputeLibrary flatbuffers protobuf-host tensorflow-protobuf builders.sh
tar -cJf /tmp/armnn-32.tar.xz ${WORKSPACE}

mkdir ${WORKSPACE}/out
mv /tmp/armnn-32.tar.xz ${WORKSPACE}/out
mv /tmp/armnn-full-32.tar.xz ${WORKSPACE}/out
cd ${WORKSPACE}/out && sha256sum > SHA256SUMS.txt
