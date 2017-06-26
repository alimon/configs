#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
  cd ${WORKSPACE}
  sudo rm -rf /srv/* /tmp/*.tgz
  rm -rf out
}

# workaround to enforce release version to major until docker image is updated
[ -f "/etc/yum/vars/releasever" ] && echo "7" | sudo tee /etc/yum/vars/releasever

cd ${WORKSPACE}/openstack-venvs
sudo ./build_all.sh

mkdir out
sudo mv /tmp/*.tgz out/
sudo chown -R buildslave:buildslave out
(cd out && sha256sum * > SHA256SUMS)

# Publish
DEST=snapshots/reference-platform/components/developer-cloud/openstack/centos-virtualenv/${BUILD_NUMBER}
if grep Debian /etc/issue 2>&1 >/dev/null ; then
  DEST=snapshots/reference-platform/components/developer-cloud/openstack/debian-virtualenv/${BUILD_NUMBER}
fi

test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  out ${DEST}
