#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -rf ${HOME}/.docker
    docker rmi linaro/registry:2
}

mkdir -p ${HOME}/.docker
sed -e "s|\${DOCKER_AUTH}|${DOCKER_AUTH}|" < ${WORKSPACE}/config.json > ${HOME}/.docker/config.json
chmod 0600 ${HOME}/.docker/config.json

rm -rf ${WORKSPACE}/*

# remove it just in case it exists from previous jobs
docker rmi linaro/registry:2

git clone --depth 1 https://git.linaro.org/leg/sdi/docker-registry-image.git
cd docker-registry-image
docker build --tag "linaro/registry:2" .
docker push linaro/registry:2
