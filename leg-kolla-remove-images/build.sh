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

docker images | grep ${kolla_tag} | awk "{print $3}" | xargs docker rmi -f || true
docker images | grep ${kolla_tag} | awk "{print $3}" | xargs docker rmi -f || true
docker images | grep ${kolla_tag} | awk "{print $3}" | xargs docker rmi -f || true
