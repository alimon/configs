#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    rm -rf ${HOME}/.docker
    rm -f ${WORKSPACE}/{log,config.json,version.txt}
}

mkdir -p ${HOME}/.docker
sed -e "s|\${DOCKER_AUTH}|${DOCKER_AUTH}|" < ${WORKSPACE}/config.json > ${HOME}/.docker/config.json
chmod 0600 ${HOME}/.docker/config.json

echo ""
echo "########################################################################"
echo "    Gerrit Environment"
env |grep '^GERRIT'
echo "########################################################################"

rm -f ${WORKSPACE}/{log,config.json,version.txt}
cd dockerfiles/

git_previous_commit=$(git rev-parse HEAD~1)
git_commit=$(git rev-parse HEAD)
files=$(git diff --name-only ${git_previous_commit} ${git_commit})
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
  dir_basename=$(basename ${dir})
  case "${dir_basename}" in
    "tcwg-"*)
      # ${dir} is one of generic tcwg-base/* directories.  Add dependent
      # images to the list.
      update_images="${update_images} $(dirname $(find . -path "*-${dir_basename}*/build.sh" | sed -e "s#^\./##g"))"
      ;;
    *)
      update_images="${update_images} $(dirname $(find ${dir} -name build.sh))"
      ;;
  esac
done
update_images="$(echo "${update_images}" | tr " " "\n" | sort -u)"

host_arch=$(dpkg-architecture -qDEB_HOST_ARCH)

for image in ${update_images}; do
  (
  cd ${image}
  image_arch=$(basename ${PWD} | cut -f2 -d '-')
  skip="skip"
  if [ -f gerrit-branches ]; then
    # Build only from branches mentioned in gerrit-branches
    if grep -q "^${GERRIT_BRANCH}\$" gerrit-branches; then
      skip="no"
    fi
  elif [ x"${GERRIT_BRANCH}" = x"master" ]; then
    # No gerrit-branch file, so build only from "master" branch.
    skip="no"
  fi
  case "${skip}:${host_arch}:${image_arch}" in
    "skip:"*)
      echo "Skipping: don't need to build ${image} on branch ${GERRIT_BRANCH}"
      ;;
    "no:amd64:amd64"|"no:amd64:i386"|"no:arm64:arm64"|"no:armhf:armhf")
      echo "=== Start build: ${image} ==="
      ./build.sh || echo "=== FAIL: ${image} ===" >> ${WORKSPACE}/log
      ;;
    *)
      echo "Skipping: can't build for ${image_arch} on ${host_arch}"
      ;;
  esac
  if [ -r .docker-tag ]; then
    docker_tag=$(cat .docker-tag)
    if [ x"${GERRIT_BRANCH}" != x"master" ]; then
      new_tag=${docker_tag}-${GERRIT_BRANCH}
      docker tag ${docker_tag} ${new_tag}
      docker_tag=${new_tag}
    fi
    docker push ${docker_tag}
  fi
  )||echo $image failed >> ${WORKSPACE}/log
done

if [ -e ${WORKSPACE}/log ]
then
    echo "some images failed:"
    cat ${WORKSPACE}/log
    exit 1
fi
