#!/bin/bash -ex

git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="python-pip openssl libssl-dev coreutils"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

# Install ruamel.yaml
pip install --user --force-reinstall ruamel.yaml

sudo apt-get update
sudo apt-get install -y selinux-utils cpio

export LKFT_WORK_DIR=/home/buildslave/srv/${BUILD_DIR}
export LKFT_BUILD_DIR=/home/buildslave/srv/${BUILD_DIR}/workspace

# temporary workaround for changing to build under ${LKFT_BUILD_DIR}
if [ -d "${LKFT_WORK_DIR}/.repo" ]; then
  sudo rm -fr ${LKFT_WORK_DIR}
fi
if [ ! -d "${LKFT_WORK_DIR}" ]; then
  sudo mkdir -p ${LKFT_WORK_DIR}
  sudo chmod 777 ${LKFT_WORK_DIR}
fi
cd ${LKFT_WORK_DIR}

# clean the workspace, but keep using the old repo for repo sync speed
LKFT_REPO_BACKUP=${LKFT_WORK_DIR_DIR}/.repo-lkft
rm -fr ${LKFT_REPO_BACKUP} && [ -d ${LKFT_BUILD_DIR}/.repo ] && mv ${LKFT_BUILD_DIR}/.repo ${LKFT_REPO_BACKUP}
rm -fr ${LKFT_BUILD_DIR} && mkdir -p ${LKFT_BUILD_DIR} && [ -d ${LKFT_REPO_BACKUP} ] && mv ${LKFT_REPO_BACKUP} ${LKFT_BUILD_DIR}/.repo
cd ${LKFT_BUILD_DIR}

wget https://android-git.linaro.org/android-build-configs.git/plain/lkft/linaro-lkft.sh?h=lkft -O linaro-lkft.sh
chmod +x linaro-lkft.sh
for build_config in ${ANDROID_BUILD_CONFIG}; do
    rm -fr out/${build_config}
    ./linaro-lkft.sh -c "${build_config}"
    mv out/${build_config}/pinned-manifest/*-pinned.xml out/${build_config}/pinned-manifest.xml
    mv out/${build_config}/kernel/.config out/${build_config}/defconfig
done
