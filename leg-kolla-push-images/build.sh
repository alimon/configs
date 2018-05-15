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

docker images | grep ${kolla_tag} | cut -d" " -f1 >list-of-images

amount=$(wc -l list-of-images | cut -d" " -f1 | sort)
current=1

echo "Going to push ${amount} of images with '${kolla_tag}' tag."

for image in $(cat list-of-images)
do
	echo "Pushing ${current} of ${amount} - ${image}"
	docker push $image:${kolla_tag}
	((current++))
done

