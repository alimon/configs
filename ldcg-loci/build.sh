#!/bin/bash

HUB_USERNAME=linaro
IMG_TAG=build-${BUILD_NUMBER}
BASE_IMG=${HUB_USERNAME}/loci-base:${IMG_TAG}

# build base image first
# it has ERP:18.06 repo enabled
# and all packages common in loci images gets preinstalled
#
docker build . --tag ${BASE_IMG}
docker push ${BASE_IMG}

# requirements needs to be built first
for project in requirements cinder glance heat horizon ironic keystone neutron nova octavia
do 
	IMG_NAME=${HUB_USERNAME}/loci-${project}:${IMG_TAG}

	if [ ${project} != 'requirements' ];then
		WHEELS_OPTS="--build-arg WHEELS=${HUB_USERNAME}/loci-requirements:${IMG_TAG}"
	fi

	docker build . \
		--build-arg PROJECT=${project} \
		--build-arg FROM=${BASE_IMG} \
		--build-arg PROFILES='lvm ceph' \
		${WHEELS_OPTS} \
		--tag ${IMG_NAME}

	docker push ${IMG_NAME}
done
