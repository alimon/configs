#!/bin/bash

set -xe

git clone --depth 1 https://git.linaro.org/ci/job/configs.git

cd configs/ldcg-hpc-tensorflow/

docker build -f Dockerfile-debian --pull --label linaro/debian-tensorflow:${BUILD_NUMBER} .
docker build -f Dockerfile-centos --pull --label linaro/centos-tensorflow:${BUILD_NUMBER} .

docker push linaro/debian-tensorflow:${BUILD_NUMBER}
docker push linaro/centos-tensorflow:${BUILD_NUMBER}
