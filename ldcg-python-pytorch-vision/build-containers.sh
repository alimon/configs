#!/bin/bash

set -xe

rm -rf ${WORKSPACE}

git clone --depth 1 https://git.linaro.org/ci/job/configs.git

cd configs/ldcg-python-pytorch-vision/

docker build -f Dockerfile-debian --pull --tag linaro/debian-pytorch:${BUILD_NUMBER} .
docker build -f Dockerfile-centos --pull --tag linaro/centos-pytorch:${BUILD_NUMBER} .

docker push linaro/debian-pytorch:${BUILD_NUMBER}
docker push linaro/centos-pytorch:${BUILD_NUMBER}
