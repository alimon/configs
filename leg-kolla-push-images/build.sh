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

docker images | grep ${kolla_tag} | cut -d" " -f1|sort >list-of-images

total=$(wc -l list-of-images | cut -d" " -f1)
current=1
errors=0
pushed=0
attempts=0

echo "Going to push ${total} of images with '${kolla_tag}' tag."

for image in $(cat list-of-images)
do
	retries='2 3 4'

	(( attempts++ ))
	echo "Pushing ${current}/${total} - ${image}:${kolla_tag}"
	docker push ${image}:${kolla_tag}

	if [ $? -eq 0 ]; then
		(( pushed++ ))
	else
		(( errors++ ))

		for retry in $retries
		do
			(( attempts++ ))
			sleep 5
			echo "Pushing ${current}/${total} - ${image}:${kolla_tag} - attempt number ${retry}"
			docker push ${image}:${kolla_tag}

			if [ $? -eq 0 ]; then
				(( pushed++ ))
				break
			fi

			(( errors++ ))
		done
	fi

	(( current++ ))
done

echo "Uploaded: ${pushed} out of ${total}"
echo "Attempts: ${attempts}"
echo "Errors: ${errors}"
