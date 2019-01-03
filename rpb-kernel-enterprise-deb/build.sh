#!/bin/bash

set -ex

echo "deb https://deb.debian.org/debian stretch-backports main" >/etc/apt/sources.list.d/backports.list

sudo apt-get update -q=2
sudo apt-get install -q -y ccache python-requests quilt cpio rsync dh-exec kernel-wedge/stretch-backports
sudo apt upgrade -q -y

# Checkout source code
git clone --depth 1 -b ${DEBIAN_GIT_BRANCH} ${DEBIAN_GIT_URL} debian-pkg

# Export the kernel packaging version
cd ${WORKSPACE}/linux

kernel_version=$(make kernelversion)
kernel_deb_pkg_version=$(echo ${kernel_version} | sed -e 's/\.0-rc/~rc/')
export KDEB_PKGVERSION="${kernel_deb_pkg_version}.dfsg.${BUILD_NUMBER}-1"
git tag -f v${kernel_deb_pkg_version//\~/-}

# Build the debian source kernel
cd ${WORKSPACE}/debian-pkg

# Use build number as ABI
sed -i "s/^abiname:.*/abiname: ${BUILD_NUMBER}/g" debian/config/defines

cat << EOF > debian/changelog
linux ($KDEB_PKGVERSION) unstable; urgency=medium

  * Auto build:
    - URL: ${GIT_URL}
    - Branch: ${GIT_BRANCH}
    - Commit: ${GIT_COMMIT}

 -- enterprise <rp-enterprise@linaro.org>>  $(date -R)

EOF

debian/rules clean || true
/usr/bin/make -f debian/rules debian/control-real || true # no need to patch packaging
debian/bin/genorig.py ../linux
debian/rules orig
fakeroot debian/rules source
debuild -S -uc -us -d
cd ..

cat > ${WORKSPACE}/build-package-params <<EOF
source=${BUILD_URL}/artifact/$(echo *.dsc)
repo=${TARGET_REPO}
EOF

# Final preparation for publishing
mkdir out
rm *.orig.tar.xz
cp -a orig/*.orig.tar.xz ${WORKSPACE}/
cp -a *.dsc *.changes *.debian.tar.xz *.orig.tar.xz out/

# Create MD5SUMS file
(cd out && md5sum * > MD5SUMS.txt)

# Build information
cat > out/HEADER.textile << EOF

h4. Reference Platform - Linux Kernel

Linux Kernel build consumed by the Reference Platform Enterprise Builds

Build Description:
* Build URL: "${BUILD_URL}":${BUILD_URL}
* Git tree: "${GIT_URL}":${GIT_URL}
* Git branch: ${GIT_BRANCH}
* Git commit: ${GIT_COMMIT}
* Kernel version: ${kernel_version}
* Kernel deb version: ${KDEB_PKGVERSION}
EOF

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  out reference-platform/components/linux/enterprise/${BUILD_NUMBER}/

