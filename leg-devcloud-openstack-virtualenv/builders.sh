#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
  cd ${WORKSPACE}
  sudo rm -rf /srv/* /tmp/*.tgz
  rm -rf out
}

sudo apt-get -q=2 update
cd ${WORKSPACE}/openstack-venvs
sudo ./build_all.sh

mkdir out
mv /tmp/*.tgz out/
(cd out && sha256sum * > SHA256SUMS)
sudo chown -R buildslave:buildslave out

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  out snapshots/developer-cloud/openstack/virtualenv/${BUILD_NUMBER}
