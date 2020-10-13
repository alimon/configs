#!/bin/bash

set -xe

git clone --depth 1 https://git.linaro.org/ci/job/configs.git

cd configs/ldcg-python-pytorch-vision/

docker build -f Dockerfile-debian --pull --label linaro/debian-pytorch:${BUILD_NUMBER} .
docker build -f Dockerfile-centos --pull --label linaro/centos-pytorch:${BUILD_NUMBER} .

docker push linaro/debian-pytorch:${BUILD_NUMBER}
docker push linaro/centos-pytorch:${BUILD_NUMBER}
