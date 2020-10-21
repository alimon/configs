#!/bin/bash

set -xe

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -rf ${HOME}/.docker
}

mkdir -p ${HOME}/.docker
sed -e "s|\${DOCKER_AUTH}|${DOCKER_AUTH}|" < ${WORKSPACE}/config.json > ${HOME}/.docker/config.json
chmod 0600 ${HOME}/.docker/config.json

rm -rf ${WORKSPACE}/*

git clone --depth 1 https://git.linaro.org/ci/job/configs.git

cd configs/ldcg-hpc-tensorflow/

docker build -f Dockerfile-debian --pull --label linaro/debian-tensorflow:${BUILD_NUMBER} .
docker build -f Dockerfile-centos --pull --label linaro/centos-tensorflow:${BUILD_NUMBER} .

docker push linaro/debian-tensorflow:${BUILD_NUMBER}
docker push linaro/centos-tensorflow:${BUILD_NUMBER}
