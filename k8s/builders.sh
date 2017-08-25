#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -rf ${HOME}/.docker
}

mkdir -p ${HOME}/.docker
sed -e "s|\${DOCKER_AUTH}|${DOCKER_AUTH}|" < ${WORKSPACE}/config.json > ${HOME}/.docker/config.json
chmod 0600 ${HOME}/.docker/config.json

rm -rf ${WORKSPACE}/*

# Build addon-resizer

git clone --depth 1 -b arm64 https://github.com/yibo-cai/autoscaler autoscaler

cd autoscaler/addon-resizer

make container ARCH=arm64

# push to linaro/addon-resizer-arm64:2.1
if [ -r .docker-tag ]; then
  docker push $(cat .docker-tag)
fi
