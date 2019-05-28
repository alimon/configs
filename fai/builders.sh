#!/bin/bash

set -e

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    echo "INFO: umount ${WORKSPACE}/builddir"
    sudo umount ${WORKSPACE}/builddir
}

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="python-pip fai-server fai-setup-storage qemu-utils procps"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

set -ex

# speed up FAI
test -d builddir || mkdir builddir
sudo mount -t tmpfs -o size=6G tmpfs builddir

# Get FAI config
git clone --depth 1 ${REPO_URL} -b ${BRANCH} fai

cd fai

git log -1

if [ -n "${GERRIT_CHANGE}" ]; then
    git pull https://review.linaro.org/ci/fai ${GERRIT_CHANGE}
fi

sudo fai-diskimage -v --cspace $(pwd) \
     --hostname linaro \
     -S ${ROOTFS_SIZE} \
     --class $(echo SAVECACHE,${FAI_CLASS} | tr '[:lower:]' '[:upper:]') \
     ${WORKSPACE}/builddir/linaro-test-fai-${BUILD_NUMBER}.img.raw

if sudo grep -E '^(ERROR:|WARNING: These unknown packages are removed from the installation list|Exit code task_)' /var/log/fai/linaro/last/fai.log
then
    echo "Errors during build"
    exit 1
fi
