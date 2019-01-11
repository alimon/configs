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

git clone --depth 1 https://git.linaro.org/ci/dockerfiles.git

cd dockerfiles/${IMAGE}/
if ! ./build.sh; then
    echo "=== FAIL: ${IMAGE} ==="
    exit 1
fi

# now we have image name in .docker-tag
if [ -r .docker-tag ]; then
    docker_tag=$(cat .docker-tag)
    docker push ${docker_tag}
fi

