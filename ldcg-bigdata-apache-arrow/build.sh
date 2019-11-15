#!/bin/sh

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

git clone --depth 1 https://github.com/apache/arrow.git

cd arrow/dev/tasks/linux-packages/

# change ownership of resulting packages to buildslave user so we can remove
# them without sudo use. "apt/build.sh" is called in a container as root user
echo "chown 11517:1001 -R /host/repositories" >> apt/build.sh

rake version:update
APT_TARGETS=debian-buster rake apt:build

mkdir -p ${WORKSPACE}/out
cp -a apache-arrow/apt/repositories/* ${WORKSPACE}/out/
echo "DEPLOY_DIR_IMAGE=${WORKSPACE}/out" >  ${WORKSPACE}/publish_parameters
echo "PUB_DEST=reference-platform/components/bigdata/apache-arrow/${BUILD_NUMBER}" >>  ${WORKSPACE}/publish_parameters
