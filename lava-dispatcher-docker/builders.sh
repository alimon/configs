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

# Build
pushd lava/dispatcher
rm -f .docker-tag
./build.sh -r ${REPOSITORY} -d stretch -a amd64
# push to linaro/lava-dispatcher-${REPOSITORY}-stretch-amd64:${docker_tag}
docker push $(cat .docker-tag)
popd
