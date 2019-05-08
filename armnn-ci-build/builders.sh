sudo apt -q=2 update
sudo apt -q=2 install -y --no-install-recommends scons cmake git g++ gcc autoconf curl libtool valgrind libpthread-stubs0-dev

mkdir armnn-tflite && cd armnn-tflite

git clone --depth 1 https://github.com/Arm-software/ComputeLibrary.git
git clone --depth 1 https://github.com/Arm-software/armnn
git clone --depth 1 -b v3.5.0 https://github.com/google/protobuf.git
git clone --depth 1 https://github.com/tensorflow/tensorflow.git
git clone --depth 1 https://github.com/google/flatbuffers.git
wget -q https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.bz2 && tar xf boost_*.tar.bz2

cd ${WORKSPACE}/armnn-tflite/ComputeLibrary
#need to add if loops for opencl=1 embed_kernels=1 and neon=1
scons -u -j$(nproc) arch=arm64-v8a extra_cxx_flags="-fPIC" benchmark_tests=1 validation_tests=1

#build Boost
cd ${WORKSPACE}/armnn-tflite/boost_*
./bootstrap.sh 
./b2  \
  --build-dir=${WORKSPACE}/boost_1_64_0/build toolset=gcc link=static cxxflags=-fPIC \
  --with-filesystem \
  --with-test \
  --with-log \
  --with-program_options install --prefix=${WORKSPACE}/boost

#build Protobuf
cd ${WORKSPACE}/armnn-tflite/protobuf
git submodule update --init --recursive
./autogen.sh
./configure --prefix=${WORKSPACE}/protobuf-host
make -j$(nproc)
make install

#generate tensorflow protobuf library
cd ${WORKSPACE}/armnn-tflite/tensorflow
../armnn/scripts/generate_tensorflow_protobuf.sh ../tensorflow-protobuf ../protobuf-host

#build google flatbuffer libraries
cd ${WORKSPACE}/armnn-tflite/flatbuffers
cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

#Build Arm NN
cd ${WORKSPACE}/armnn-tflite/armnn
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
