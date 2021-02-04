#!/bin/bash -ex

set -o pipefail

# call api of android.linaro.org for lkft report check scheduling
if [ -n "${KERNEL_BRANCH}" ] && [ -n "${KERNEL_DESCRIBE}" ] && [ -n "${JOB_NAME}" ] && [ -n "${BUILD_NUMBER}" ]; then

    # environments set by the upstream trigger job
    KERNEL_COMMIT=${SRCREV_kernel}
    if [ -n "${MAKE_KERNELVERSION}" ] && echo "X${USE_KERNELVERSION_FOR_QA_BUILD_VERSION}" | grep -i "Xtrue"; then
        QA_BUILD_VERSION=${MAKE_KERNELVERSION}-${KERNEL_COMMIT:0:12}
    elif [ ! -z "${KERNEL_DESCRIBE}" ]; then
        QA_BUILD_VERSION=${KERNEL_DESCRIBE}
    else
        QA_BUILD_VERSION=${KERNEL_COMMIT:0:12}
    fi

    curl -L https://android.linaro.org/lkft/newbuild/${KERNEL_BRANCH}/${QA_BUILD_VERSION}/${JOB_NAME}/${BUILD_NUMBER} || true
fi

git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"

#change to use python3 by default
if ! python --version|grep 3; then
  sudo rm -fv /usr/bin/python && sudo ln -s /usr/bin/python3 /usr/bin/python
fi

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="python3-pip openssl libssl-dev coreutils"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

# Install ruamel.yaml and Jinja2 for submit_for_testing.py
# to submit jobs
pip3 install --user --force-reinstall ruamel.yaml Jinja2

sudo apt-get update
sudo apt-get install -y selinux-utils cpio

export LKFT_WORK_ROOT_DIR=/home/buildslave/srv/${BUILD_DIR}
# NOTE: LKFT_WORK_DIR used by linaro-lkft.sh as well
export LKFT_WORK_DIR=${LKFT_WORK_ROOT_DIR}/workspace

# temporary workaround for changing to build under ${LKFT_WORK_DIR}
if [ -d "${LKFT_WORK_ROOT_DIR}/.repo" ]; then
  sudo rm -fr ${LKFT_WORK_ROOT_DIR}
fi
if [ ! -d "${LKFT_WORK_ROOT_DIR}" ]; then
  sudo mkdir -p ${LKFT_WORK_ROOT_DIR}
  sudo chmod 777 ${LKFT_WORK_ROOT_DIR}
fi
cd ${LKFT_WORK_ROOT_DIR}

# clean the workspace, but keep using the old repo for repo sync speed
LKFT_REPO_BACKUP=${LKFT_WORK_ROOT_DIR}/.repo-lkft
LKFT_REPO_UNDER_WORK_DIR=${LKFT_WORK_DIR}/.repo
rm -fr ${LKFT_REPO_BACKUP} && [ -d ${LKFT_REPO_UNDER_WORK_DIR} ] && mv ${LKFT_REPO_UNDER_WORK_DIR} ${LKFT_REPO_BACKUP}
rm -fr ${LKFT_WORK_DIR} && mkdir -p ${LKFT_WORK_DIR} && [ -d ${LKFT_REPO_BACKUP} ] && mv ${LKFT_REPO_BACKUP} ${LKFT_REPO_UNDER_WORK_DIR}

cd ${LKFT_WORK_DIR}

# temporary workaround for clean workspace,
# will be reverted after one build finished successfully
rm -fr .repo

PRIVATE_CONFIG_PATH=""
if [ -n "${ANDROID_BUILD_CONFIG_REPO_URL}" ]; then
    PRIVATE_CONFIG_PATH="${LKFT_WORK_DIR}/android-build-configs-private"
    rm -fr ${PRIVATE_CONFIG_PATH}
    git clone -b lkft ${ANDROID_BUILD_CONFIG_REPO_URL} ${PRIVATE_CONFIG_PATH}
fi

wget https://android-git.linaro.org/android-build-configs.git/plain/lkft/linaro-lkft.sh?h=lkft -O linaro-lkft.sh
chmod +x linaro-lkft.sh
for build_config in ${ANDROID_BUILD_CONFIG}; do
    rm -fr out/${build_config}

    if [ -n "${PRIVATE_CONFIG_PATH}" ]; then
        ./linaro-lkft.sh -c "${build_config}" -cu "${PRIVATE_CONFIG_PATH}/lkft/${build_config}"
    else
        ./linaro-lkft.sh -c "${build_config}"
    fi
    mv out/${build_config}/pinned-manifest/*-pinned.xml out/${build_config}/pinned-manifest.xml

    # should be only one .config after the above steps
    # which is the case of using build/build.sh
    if [ -d out/${build_config}/vendor-kernel ]; then
      f_config=`find out/${build_config}/vendor-kernel -name .config`
      if [ -f "${f_config}" ]; then
        mv "${f_config}" out/${build_config}/vendor_defconfig
      fi
    fi
    if [ -d out/${build_config}/gki-kernel ]; then
      f_config=`find out/${build_config}/gki-kernel -name .config`
      if [ -f "${f_config}" ]; then
        mv "${f_config}" out/${build_config}/gki_defconfig
      fi
    fi
done
