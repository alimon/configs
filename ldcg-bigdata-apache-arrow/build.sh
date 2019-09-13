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

# to change when https://github.com/apache/arrow/pull/5024 gets merged
# git clone --depth 1 https://github.com/apache/arrow.git

git clone --depth 1 https://github.com/hrw/arrow.git

cd arrow/dev/tasks/linux-packages/

# change ownership of resulting packages to Jenkins user so we can remove them
# without sudo use. "apt/build.sh" is called in a container as root user
echo "chown 1001:1001 -R /host/repositories" >> apt/build.sh

rake version:update
APT_TARGETS=debian-stretch,debian-buster rake apt

mkdir -p ${WORKSPACE}/out
cp -a apt/repositories/* ${WORKSPACE}/out/

export DEPLOY_DIR_IMAGE=${WORKSPACE}/out/
