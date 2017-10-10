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

# Build addon-resizer
pushd git-autoscaler/addon-resizer
rm -f .docker-tag
make container ARCH=arm64
# push to linaro/addon-resizer-arm64:2.1
docker push $(cat .docker-tag)
popd
