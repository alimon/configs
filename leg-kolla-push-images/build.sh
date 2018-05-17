#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

docker_push_logs_dir="./docker_push_logs"
docker_push_retries=3

cleanup_exit()
{
    test -d ${docker_push_logs_dir} && cat ${docker_push_logs_dir}/*/**/std* jobs.log && rm -fr ${docker_push_logs_dir} jobs.log
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

parallel -tu --results ${docker_push_logs_dir} --joblog jobs.log --env kolla_tag --will-cite -k --max-procs $(nproc --all) --retries ${docker_push_retries} 'echo 'Pushing {#} of {= '$_=total_jobs()' =} - {}' && /usr/bin/docker push {}:${kolla_tag}' ::: $(cat list-of-images)
