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

rm -rf ${WORKSPACE}/*

git clone --depth 1 https://git.openstack.org/openstack/kolla

virtualenv --python=/usr/bin/python2 venv-for-kolla
. venv-for-kolla/bin/activate

cd kolla

pip install -r requirements.txt

mkdir -p logs/debian-source

kolla_namespace=linaro-sdi # not yet chosen
./tools/build.py --base debian \
                 --base-image arm64v8/debian \
                 --format none \
                 --logs-dir logs/debian-source \
                 --pull \
                 --retries 0 \
                 --type source \
                 --namespace ${kolla_namespace}
#
# Here need to add code to push images to hub.docker.com
#

docker images | grep ${kolla_namespace} | sort

# Publish logs
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --link-latest \
  logs/debian-source reference-platform/enterprise/components/openstack/kolla-logs/${BUILD_NUMBER}
