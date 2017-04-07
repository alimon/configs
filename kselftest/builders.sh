#!/bin/bash

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi

pkg_list="git libcap-dev libcap-ng-dev libfuse-dev libmount-dev libpopt-dev pkg-config pxz rsync"
deb_host_arch=$(dpkg-architecture -qDEB_HOST_ARCH)
case "${deb_host_arch}" in
  amd64)
    export ARCH=x86_64
    pkg_list+=" libnuma-dev"
    ;;
  arm64)
    export ARCH=arm64
    pkg_list+=" libnuma-dev"
    ;;
  armhf)
    export ARCH=arm
    ;;
esac

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

KSELFTEST_URL=${KSELFTEST_URL:-"https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"}
KSELFTEST_BRANCH=${KSELFTEST_BRANCH:-"master"}
WORKSPACE=${WORKSPACE:-"${PWD}"}

set -x

git clone -b ${KSELFTEST_BRANCH} ${KSELFTEST_URL} ${WORKSPACE}
git_describe=$(git describe)
echo "#${BUILD_NUMBER}-${git_describe}" > version.txt

make ARCH=${ARCH} headers_install
export INSTALL_PATH=kselftest
make ARCH=${ARCH} -C tools/testing/selftests
make ARCH=${ARCH} -C tools/testing/selftests install

mkdir -p tools/testing/selftests/out
cd tools/testing/selftests
tar -I pxz -cf out/kselftest_${ARCH}_${git_describe}.tar.xz kselftest

# Build information
cat > out/HEADER.textile << EOF

h4. kselftest

Build description:
* Build URL: "${BUILD_URL}":${BUILD_URL}
* Kernel URL: ${KSELFTEST_URL}
* Kernel branch: ${KSELFTEST_BRANCH}
* Kernel commit: ${git_describe}
EOF

cat > out/build_config.json <<EOF
{
  "kernel_repo" : "${KSELFTEST_URL}",
  "kernel_branch" : "${KSELFTEST_BRANCH}",
  "kernel_commit_id" : "${git_describe}"
}
EOF
