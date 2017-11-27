#!/bin/bash

set -e

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -rf ${HOME}/.docker
}

mkdir -p ${HOME}/.docker
sed -e "s|\${DOCKER_AUTH}|${DOCKER_AUTH}|" < ${WORKSPACE}/config.json > ${HOME}/.docker/config.json
chmod 0600 ${HOME}/.docker/config.json

docker build -t linaro/compass-tasks:latest compass-tasks
docker push linaro/compass-tasks:latest

docker build -t linaro/compass-tasks-k8s:latest compass-tasks-k8s
docker push linaro/compass-tasks-k8s:latest
