#!/bin/bash

set -xe

trap cleanup_exit EXIT INT TERM ERR

cleanup_exit()
{
    rm -rf ${HOME}/.docker
}

rm -rf ${WORKSPACE}

mkdir -p ${HOME}/.docker
sed -e "s|\${DOCKER_AUTH}|${DOCKER_AUTH}|" < ${WORKSPACE}/config.json > ${HOME}/.docker/config.json
chmod 0600 ${HOME}/.docker/config.json

git clone --depth 1 https://git.linaro.org/ci/job/configs.git

cd configs/ldcg-python-pytorch-vision/

docker build -f Dockerfile-debian --pull --tag linaro/debian-pytorch:${BUILD_NUMBER} .
docker build -f Dockerfile-centos --pull --tag linaro/centos-pytorch:${BUILD_NUMBER} .

docker push linaro/debian-pytorch:${BUILD_NUMBER}
docker push linaro/centos-pytorch:${BUILD_NUMBER}
