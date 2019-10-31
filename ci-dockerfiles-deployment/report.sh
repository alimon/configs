#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -rf ${HOME}/.docker
    rm -f ${WORKSPACE}/{log,config.json,version.txt}
}

update_images=$(find -type f -name .docker-tag)

for imagename in ${update_images}; do
  (
    docker_tag=$(cat $imagename)
    if [ x"${GERRIT_BRANCH}" != x"master" ]; then
      new_tag=${docker_tag}-${GERRIT_BRANCH}
      docker tag ${docker_tag} ${new_tag}
      docker_tag=${new_tag}
    fi
    echo successful build ${docker_tag}
  )
done

if [ -e ${WORKSPACE}/log ]
then
    echo "some images failed:"
    cat ${WORKSPACE}/log
    exit 1
fi
