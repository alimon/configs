#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -rf "${HOME}/.docker"
    rm -rf "${WORKSPACE}/dockerfiles"
}

mkdir -p "${HOME}/.docker"
sed -e "s|\${DOCKER_AUTH}|${DOCKER_AUTH}|" < "${WORKSPACE}/config.json" > "${HOME}/.docker/config.json"
chmod 0600 "${HOME}/.docker/config.json"

testdef_tag="$(git describe --tags --abbrev=0)"

rm -rf "${WORKSPACE}/dockerfiles"
git clone https://git.linaro.org/ci/dockerfiles.git

build_img() {
    docker_img="$1"
    cd "${WORKSPACE}/dockerfiles/${docker_img}"
    ./build.sh "${testdef_tag}"

    # Push to linaro/testdef-*
    docker push "$(cat .docker-tag)"
}

build_img "stretch-armhf-testdef"
