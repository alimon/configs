#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -rf ${HOME}/.docker
    rm -f ${WORKSPACE}/{log,config.json,version.txt}
}

docker_log_in()
{
    mkdir -p ${HOME}/.docker
    sed -e "s|\${DOCKER_AUTH}|${DOCKER_AUTH}|" < ${WORKSPACE}/config.json > ${HOME}/.docker/config.json
    chmod 0600 ${HOME}/.docker/config.json
}

update_images=$(find -type f -name .docker-tag)
docker_log_in
for imagename in ${update_images}; do
  (
    docker_tag=$(cat $imagename)
    if [ x"${GERRIT_BRANCH}" != x"master" ]; then
      new_tag=${docker_tag}-${GERRIT_BRANCH}
      docker tag ${docker_tag} ${new_tag}
      docker_tag=${new_tag}
    fi
    for i in 30 60 120;
    do
        docker push ${docker_tag} && exit 0 || true
        sleep $i
        docker_log_in
    done
    exit 1
  )||echo $imagename push failed >> ${WORKSPACE}/log
done

if [ -e ${WORKSPACE}/log ]
then
    echo "some images failed:"
    cat ${WORKSPACE}/log
    exit 1
fi
