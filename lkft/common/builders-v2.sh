#!/bin/bash -ex

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
    curl -L http://213.146.155.43/lkft/newbuild/${KERNEL_BRANCH}/${QA_BUILD_VERSION}/${JOB_NAME}/${BUILD_NUMBER} || true
fi

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

wget https://android-git.linaro.org/android-build-configs.git/plain/lkft/linaro-lkft.sh?h=lkft -O linaro-lkft.sh
chmod +x linaro-lkft.sh
for build_config in ${ANDROID_BUILD_CONFIG}; do
    rm -fr out/${build_config}
    ./linaro-lkft.sh -c "${build_config}"
    mv out/${build_config}/pinned-manifest/*-pinned.xml out/${build_config}/pinned-manifest.xml
    [ -f out/${build_config}/kernel/.config ] && mv out/${build_config}/kernel/.config out/${build_config}/defconfig
    [ -f out/${build_config}/gki-kernel/.config ] &&  mv out/${build_config}/gki-kernel/.config out/${build_config}/gki_defconfig

    # should be only one .config after the above steps
    # which is the case of using build/build.sh
    f_config=`find out/${build_config}/ -name .config`
    [ -f "${f_config}" ] && mv "${f_config}" out/${build_config}/${build_config}_/gki_defconfig
done
