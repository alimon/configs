#!/bin/bash
# build dependencies on Debian:
# git build-essential virtualenv python-dev libffi-dev libssl-dev

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

kolla_tag=queens-$(date +"%Y%m%d") # use YYYYMMDD for tags

kolla_namespace=linaro
./tools/build.py --base debian \
                 --format none \
                 --logs-dir logs/debian-source \
                 --pull \
                 --push \
                 --retries 0 \
                 --tag ${kolla_tag} \
                 --type source \
                 --namespace ${kolla_namespace} || true

docker images | grep ${kolla_tag} | sort

# remove all images as they are pushed to hub.docker.com and won't be used
# do in a loop as we remove in random order and some have children images
for run in 1 2 3 4 5
do
	docker images | grep ${kolla_tag} | awk '{print $3}' | xargs docker rmi -f 2>&1 >/dev/null || true
done
