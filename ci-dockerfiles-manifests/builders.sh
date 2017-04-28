#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -rf ${HOME}/.docker
}

if ! sudo apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo apt-get -q=2 update || true
fi
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y manifest-tool; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y manifest-tool
fi

mkdir -p ${HOME}/.docker
sed -e "s|\${DOCKER_AUTH}|${DOCKER_AUTH}|" < ${WORKSPACE}/config.json > ${HOME}/.docker/config.json
chmod 0600 ${HOME}/.docker/config.json

rm -rf ${WORKSPACE}/*

git clone --depth 1 https://git.linaro.org/ci/docker-manifests.git
cd docker-manifests
for manifest in *.yaml; do
  manifest-tool push from-spec ${manifest}
done
