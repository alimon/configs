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

echo ""
echo "########################################################################"
echo "    Gerrit Environment"
env |grep '^GERRIT'
echo "########################################################################"

rm -rf ${WORKSPACE}/*

git clone -b ${GERRIT_BRANCH} --depth 2 https://review.linaro.org/${GERRIT_PROJECT}
cd *
git fetch https://review.linaro.org/${GERRIT_PROJECT} ${GERRIT_REFSPEC}
git checkout -q FETCH_HEAD

git_previous_commit=$(git rev-parse HEAD~1)
files=$(git diff --name-only ${git_previous_commit} ${GERRIT_PATCHSET_REVISION})
echo Changes in: ${files}
changed_dirs=$(dirname ${files})

update_images=""
for dir in ${changed_dirs}; do
  # Find the closest directory with build.sh.  This is, primarily,
  # to handle changes to tcwg-base/tcwg-build/tcwg-builslave/* directories.
  while [ ! -e ${dir}/build.sh -a ! -e ${dir}/.git ]; do
    dir=$(dirname ${dir})
  done
  # Add this and all dependant images in the update.
  update_images="${update_images} $(dirname $(find ${dir} -name build.sh))"
done

host_arch=$(dpkg-architecture -qDEB_HOST_ARCH)

for image in ${update_images}; do
  (
  cd ${image}
  image_arch=$(basename ${PWD} | cut -f2 -d '-')
  case "${image_arch}" in
    amd64|i386)
      if [ "${host_arch}" = "amd64" ]; then
        echo "=== Start build: ${image} ==="
        ./build.sh || echo "=== FAIL: ${image} ===" >> ${WORKSPACE}/log
      fi
      ;;
    arm64|armhf)
      if [ "${host_arch}" = "arm64" ]; then
        echo "=== Start build: ${image} ==="
        ./build.sh || echo "=== FAIL: ${image} ===" >> ${WORKSPACE}/log
      fi
      ;;
    *)
      echo "unknown arch: ${image_arch}"
      ;;
  esac
  if [ -r .docker-tag ]; then
    docker push $(cat .docker-tag)
  fi
  )||echo $image failed >> ${WORKSPACE}/log
done

if [ -e ${WORKSPACE}/log ]
then
    echo "some images failed:"
    cat ${WORKSPACE}/log
    exit 1
fi
