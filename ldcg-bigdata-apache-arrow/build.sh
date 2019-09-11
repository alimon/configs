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

APT_TARGETS=debian-stretch,debian-buster rake apt

mkdir -p ${WORKSPACE}/out
cp -a apt/repositories/* ${WORKSPACE}/out/

sudo chown -R buildslave:buildslave ${WORKSPACE}/out
