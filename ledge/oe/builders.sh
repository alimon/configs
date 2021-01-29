#!/bin/bash

echo "LEDGE build for machine ${MACHINE} distro ${DISTRO}"
ORIG_MACHINE="${MACHINE}"

set -e

# workaround EDK2 is confused by the long path used during the build
# and truncate files name expected by VfrCompile
sudo mkdir -p /srv/oe
sudo chown buildslave:buildslave /srv/oe
cd /srv/oe

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    echo "Running cleanup_exit..."
}

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi

pkg_list="bc ccache chrpath cpio diffstat gawk git expect pkg-config python-pip python-requests python-crypto texinfo wget zlib1g-dev libglib2.0-dev libpixman-1-dev python python3 sudo libelf-dev xz-utils pigz coreutils curl libcurl4-openssl-dev libc6-dev-i386 g++-multilib"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

sudo locale-gen en_US.UTF-8 && sudo update-locale LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# install required python modules
pip install --user --force-reinstall Jinja2 ruamel.yaml

set -ex

# Store the home repository
if [ -z "${WORKSPACE}" ]; then
  # Local build
  export WORKSPACE=${PWD}
fi

mkdir -p ${HOME}/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
chmod a+x ${HOME}/bin/repo
export PATH=${HOME}/bin:${PATH}

# initialize repo if not done already
export MANIFEST_URL=${MANIFEST_URL:-https://github.com/Linaro/ledge-oe-manifest.git}
if [ ! -e ".repo/manifest.xml" ]; then
   repo init --no-clone-bundle --depth=1 --no-tags -u ${MANIFEST_URL} -b ${MANIFEST_BRANCH}

   if [ -z "${RELEASE}" ]; then
     # link to shared downloads on persistent disk
     # our builds config is expecting downloads and sstate-cache, here.
     # DL_DIR = "${OEROOT}/sources/downloads"
     # SSTATE_DIR = "${OEROOT}/build/sstate-cache"
     mkdir -p ${HOME}/srv/oe/downloads ${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH}
     mkdir -p build
     ln -s ${HOME}/srv/oe/downloads
     ln -s ${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH} sstate-cache
   fi
fi

if [ "${ghprbGhRepository}" == "Linaro/ledge-oe-manifest" ]; then
    cd .repo/manifests
    git fetch origin pull/${ghprbPullId}/head:prbranch
    git checkout prbranch
    cd -
fi

repo sync

if [ "${ghprbGhRepository}" == "Linaro/meta-ledge" ]; then
    cd ./layers/meta-ledge
    git fetch github pull/${ghprbPullId}/head:prbranch
    git checkout prbranch
    cd -
fi

cp .repo/manifest.xml source-manifest.xml
repo manifest -r -o pinned-manifest.xml
MANIFEST_COMMIT=$(cd .repo/manifests && git rev-parse --short HEAD)
echo "MANIFEST_COMMIT=${MANIFEST_COMMIT}" > ${WORKSPACE}/submit_for_testing_parameters

# record changes since last build, if available
BASE_URL=http://snapshots.linaro.org
if wget -q ${BASE_URL}${PUB_DEST/\/${BUILD_NUMBER}\//\/latest\/}/pinned-manifest.xml -O pinned-manifest-latest.xml; then
    repo diffmanifests ${PWD}/pinned-manifest-latest.xml ${PWD}/pinned-manifest.xml > manifest-changes.txt
else
    echo "latest build published does not have pinned-manifest.xml, skipping diff report"
fi

# the setup-environment will create auto.conf and site.conf
# make sure we get rid of old config.
# let's remove the previous TMPDIR as well.
# we want to preserve build/buildhistory though.
rm -rf build/conf build/tmp-*glibc/
rm -rf build-${DISTRO}

source setup-environment

# use opensource OSF repository
cat << EOF >> conf/local.conf
OSF_LMP_GIT_URL = "github.com"
OSF_LMP_GIT_NAMESPACE = "opensourcefoundries/"
EOF

# get build stats to make sure that we use sstate properly
cat << EOF >> conf/auto.conf
INHERIT += "buildstats buildstats-summary"
EOF

# allow the top level job to append to auto.conf
if [ -f ${WORKSPACE}/auto.conf ]; then
    cat ${WORKSPACE}/auto.conf >> conf/auto.conf
fi

# add useful debug info
cat conf/{site,auto}.conf

BIMAGES=""
case "${ORIG_MACHINE}" in
	ledge-multi-armv7)
		for i in ${IMAGES}; do BIMAGES+="mc:qemuarm:$i "; done
		;;
	ledge-multi-armv8)
		for i in ${IMAGES}; do BIMAGES+="mc:qemuarm64:$i "; done
		;;
	*)
		BIMAGES=${IMAGES}
		;;
esac

export BB_NUMBER_THREADS=4

# For armv7 multi some bug compiling images in one command
# time bitbake ${BIMAGES} ${FIRMWARE}
for target in ${BIMAGES} ${FIRMWARE}; do
	time bitbake ${target}
done

TOPDIR=$(bitbake -e | grep "^TOPDIR="| cut -d'=' -f2 | tr -d '"')
DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE="| cut -d'=' -f2 | tr -d '"')

case "${ORIG_MACHINE}" in
	ledge-multi-armv7)
		UPLOAD_DIR="${TOPDIR}/armhf-glibc/deploy/images"
		;;
	ledge-multi-armv8)
		UPLOAD_DIR="${TOPDIR}/arm64-glibc/deploy/images"
		;;
	*)
		UPLOAD_DIR="${DEPLOY_DIR_IMAGE}"
		;;
esac

build_ledgerp_docs() {
	# Install deps
	pkg_list="python-sphinx texlive texlive-latex-extra libalgorithm-diff-perl \
                  texlive-humanities texlive-generic-recommended texlive-generic-extra \
                  latexmk"
	if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
	  echo "INFO: apt install error - try again in a moment"
	  sleep 15
	  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
	fi
	pip install --user --upgrade Sphinx
	export SPHINXBUILD=~/.local/bin/sphinx-build
	# Build docs
	cd ../layers/ledge-doc
	make latexpdf
	make installpdf DESTDIR=${UPLOAD_DIR}/
	cd -
}

build_ledgerp_docs

# Prepare files to publish
mv /srv/oe/{source,pinned}-manifest.xml ${UPLOAD_DIR}
cat ${UPLOAD_DIR}/pinned-manifest.xml

for rootfs in $(find ${UPLOAD_DIR} -type f -name *.rootfs.wic); do
	case "${MACHINE}" in
	ledge-stm32mp157c-dk2)
		mv ${rootfs} ${rootfs}.bin
		pigz -9 ${rootfs}.bin
		;;
	*)
		pigz -9 ${rootfs}
		;;
	esac
done

for cert in $(find ${UPLOAD_DIR} -type f -name ledge-kernel-uefi-certs*.wic); do
	pigz -9 ${cert}
done

# Create MD5SUMS file
find ${UPLOAD_DIR} -type f | xargs md5sum > MD5SUMS.txt
sed -i "s|${UPLOAD_DIR}/||" MD5SUMS.txt
mv MD5SUMS.txt ${UPLOAD_DIR}

# Note: the main job script allows to override the default value for
#       BASE_URL and PUB_DEST, typically used for OE RPB builds
cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEPLOY_DIR_IMAGE=${UPLOAD_DIR}
EOF

# Build information
cat > ${UPLOAD_DIR}/HEADER.textile << EOF

h4. LEDGE - OpenEmbedded

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Manifest URL: "${MANIFEST_URL}":${MANIFEST_URL}
* Manifest branch: ${MANIFEST_BRANCH}
* Manifest commit: "${MANIFEST_COMMIT}":${MANIFEST_URL/.git/\/commit}/${MANIFEST_COMMIT}
EOF

if [ -e "/srv/oe/manifest-changes.txt" ]; then
  # the space after pre.. tag is on purpose
  cat > ${UPLOAD_DIR}/README.textile << EOF

h4. Manifest changes

pre.. 
EOF
  cat /srv/oe/manifest-changes.txt >> ${UPLOAD_DIR}/README.textile
  mv /srv/oe/manifest-changes.txt ${UPLOAD_DIR}
fi

GCCVERSION=$(bitbake -e | grep "^GCCVERSION="| cut -d'=' -f2 | tr -d '"')
TARGET_SYS=$(bitbake -e | grep "^TARGET_SYS="| cut -d'=' -f2 | tr -d '"')
TUNE_FEATURES=$(bitbake -e | grep "^TUNE_FEATURES="| cut -d'=' -f2 | tr -d '"')
STAGING_KERNEL_DIR=$(bitbake -e | grep "^STAGING_KERNEL_DIR="| cut -d'=' -f2 | tr -d '"')

find ${UPLOAD_DIR}

BOOT_IMG=$(find ${UPLOAD_DIR} -type f -name "boot*${MACHINE}.img" -printf "%f\n"| sort)
KERNEL_IMG=$(find ${UPLOAD_DIR} -type f -name "*Image-*${MACHINE}*.bin" -printf "%f\n")
ROOTFS_IMG=$(find ${UPLOAD_DIR} -type f -name "ledge-iot-lava-*${MACHINE}*.rootfs.wic.gz" -printf "%f\n" )
ROOTFS_GW=$(find ${UPLOAD_DIR} -type f -name "ledge-iot-lava-*${MACHINE}*.rootfs.wic.gz" -printf "%f\n" )
ROOTFS_EXT4=$(find ${UPLOAD_DIR} -type f -name "ledge-*${MACHINE}*.rootfs.ext4.gz" -printf "%f\n")
ROOTFS_TARXZ_IMG=$(find ${UPLOAD_DIR} -type f -name "ledge-*${MACHINE}*.rootfs.tar.xz" -printf "%f\n")
HDD_IMG=$(find ${UPLOAD_DIR} -type f -name "ledge-*${MACHINE}*.hddimg.xz" -printf "%f\n")
INITRD_URL=""
OVMF=$(find ${UPLOAD_DIR} -type f -name "ovmf.qcow2" -printf "%f\n")
CERTS=$(find ${UPLOAD_DIR} -type f -name ledge-kernel-uefi-certs*.wic.gz -printf "%f\n");
FIRMWARE=$(find ${UPLOAD_DIR} -type f -name firmware.uefi.uboot.bin -printf "%f\n");

case "${MACHINE}" in
  ledge-am57xx-evm)
    # QEMU arm 32bit needs the zImage file, not the uImage file.
    # KERNEL_IMG is not used for the real hardware itself.
    KERNEL_IMG=$(find ${UPLOAD_DIR} -type f -name "zImage-*${MACHINE}*.bin" -printf "%f\n")
    ;;
  ledge-synquacer)
	  INITRD_URL="http://images.validation.linaro.org/synquacer/hc/initrd.img"
	  # We don't upload kernel images anymore, override this for synquacer since
	  # we can't install and boot the whole image.
	  KERNEL_IMG='Image-for-debian'
    ;;
  ledge-stm32mp157c-dk2)
	  cd ${DEPLOY_DIR_IMAGE}
	  tar -cpzf ../ledge-stm32mp157c-dk2.tar.gz .
	  mv ../ledge-stm32mp157c-dk2.tar.gz .
	  cd -
	  RIMAGE=ledge-stm32mp157c-dk2.tar.gz
	  # Only use the iot flashlayout to deploy, since it's a superset of the
	  # gateway image
	  FLASH_LAYOUT=$(find ${UPLOAD_DIR} -type f -name "FlashLayout_sdcard_${MACHINE}-*iot-lava*.tsv" -printf "%f\n")
    ;;
  juno)
    DTB_IMG=$(find ${UPLOAD_DIR} -type f -name "*Image-*${MACHINE}*.dtb" -printf "%f\n")
    ;;
esac

# Prepare images for LAVA
case "${ORIG_MACHINE}" in
	ledge-multi-armv7)
	rm -rf ${UPLOAD_DIR}/lava-images/
	mkdir -p ${UPLOAD_DIR}/lava-images/
	for i in ${IMAGES}; do
		mkdir -p ${UPLOAD_DIR}/lava-images/${i}/

		cp ${UPLOAD_DIR}/ledge-qemuarm/${i}-ledge-qemuarm-*.rootfs.ext4 ${UPLOAD_DIR}/lava-images/${i}/
		cp ${UPLOAD_DIR}/ledge-qemuarm/${i}-ledge-qemuarm-*.bootfs.vfat ${UPLOAD_DIR}/lava-images/${i}/
		cp ${UPLOAD_DIR}/ledge-qemuarm/FlashLayout_sdcard_*${i}-ledge-qemuarm.tsv ${UPLOAD_DIR}/lava-images/${i}/

		cp ${UPLOAD_DIR}/ledge-qemuarm/*.stm32 ${UPLOAD_DIR}/lava-images/${i}/
		cp -r ${UPLOAD_DIR}/ledge-stm32mp157c-dk2/* ${UPLOAD_DIR}/lava-images/${i}/

		cd ${UPLOAD_DIR}/lava-images/${i}

		sed -i 's/rootfs.wic.bin/rootfs.ext4/' FlashLayout_sdcard_*${i}*.tsv
		cp FlashLayout_sdcard_*${i}*.tsv ${UPLOAD_DIR}/lava-images/ledge-stm32mp157c-dk2-$i.tsv

		#Create final tar
		tar -czvf ${UPLOAD_DIR}/lava-images/ledge-stm32mp157c-dk2-$i.tar.gz .
		#Cleanup
		rm -rf ${UPLOAD_DIR}/lava-images/${i}
	done

	mkdir -p ${UPLOAD_DIR}/lava-images/debian
	cd ${UPLOAD_DIR}/lava-images/debian
	cp ${UPLOAD_DIR}/ledge-qemuarm/*-ledge-qemuarm-*.bootfs.vfat.gz ${UPLOAD_DIR}/lava-images/debian/
	cp ${UPLOAD_DIR}/ledge-qemuarm/zImage-for-debian ${UPLOAD_DIR}/lava-images/debian/

	rm -rf ${UPLOAD_DIR}/ledge-qemuarm/*.stm32
	rm -rf ${UPLOAD_DIR}/ledge-qemuarm/*.tsv
		;;
	*)
		;;
esac

# Clean up not needed build artifacts
CLEAN="Image-ledge* modules-*-mainline* \
	*.env *.conf *.json *.wks \
	dtb \
	*.txt \
        *.vfat *.ext4 \
	fip.bin \
	"
for c in ${CLEAN}; do
	find ${UPLOAD_DIR} -name $c -exec rm -rf '{}' '+'
done
find ${UPLOAD_DIR} -type l -delete

case "${ORIG_MACHINE}" in
	ledge-multi-armv7)
		PUB_DEST="${PUB_DEST}/ledge-qemuarm"
		;;
	ledge-multi-armv8)
		PUB_DEST="${PUB_DEST}/ledge-qemuarm64"
		;;
	*)
		;;
esac

cat > ${UPLOAD_DIR}/build_config.json <<EOF
{
  "kernel_repo" : "${KERNEL_REPO}",
  "kernel_commit_id" : "${SRCREV_kernel}",
  "make_kernelversion" : "${MAKE_KERNELVERSION}",
  "kernel_branch" : "${KERNEL_BRANCH}",
  "kernel_describe" : "${KERNEL_DESCRIBE}",
  "kselftest_mainline_url" : "${KSELFTESTS_MAINLINE_URL}",
  "kselftest_mainline_version" : "${KSELFTESTS_MAINLINE_VERSION}",
  "kselftest_next_url" : "${KSELFTESTS_NEXT_URL}",
  "kselftest_next_version" : "${KSELFTESTS_NEXT_VERSION}",
  "ltp_url" : "${LTP_URL}",
  "ltp_version" : "${LTP_VERSION}",
  "ltp_revision" : "${LTP_REVISION}",
  "libhugetlbfs_url" : "${LIBHUGETLBFS_URL}",
  "libhugetlbfs_version" : "${LIBHUGETLBFS_VERSION}",
  "libhugetlbfs_revision" : "${LIBHUGETLBFS_REVISION}",
  "build_arch" : "${TUNE_FEATURES}",
  "compiler" : "${TARGET_SYS} ${GCCVERSION}",
  "build_location" : "${BASE_URL}/${PUB_DEST}"
}
EOF

cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEPLOY_DIR_IMAGE=${UPLOAD_DIR}
MANIFEST_COMMIT=${MANIFEST_COMMIT}
BASE_URL=${BASE_URL}
BOOT_URL=${BASE_URL}/${PUB_DEST}/${BOOT_IMG}
ROOTFS_SPARSE_BUILD_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_IMG}
SYSTEM_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_IMG}
SYSTEM_URL_GW=${BASE_URL}/${PUB_DEST}/${ROOTFS_IMG_GW}
KERNEL_URL=${BASE_URL}/${PUB_DEST}/${KERNEL_IMG}
DTB_URL=${BASE_URL}/${PUB_DEST}/${DTB_IMG}
RECOVERY_IMAGE_URL=${BASE_URL}/${PUB_DEST}/${RIMAGE}
RECOVERY_IMAGE_LAYOUT=${BASE_URL}/${PUB_DEST}/${FLASH_LAYOUT}
NFSROOTFS_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_TARXZ_IMG}
EXT4_IMAGE_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_EXT4}
HDD_URL=${BASE_URL}/${PUB_DEST}/${HDD_IMG}
KERNEL_COMMIT=${SRCREV_kernel}
KERNEL_CONFIG_URL=${BASE_URL}/${PUB_DEST}/config
KERNEL_DEFCONFIG_URL=${BASE_URL}/${PUB_DEST}/defconfig
KSELFTESTS_MAINLINE_URL=${KSELFTESTS_MAINLINE_URL}
KSELFTESTS_MAINLINE_VERSION=${KSELFTESTS_MAINLINE_VERSION}
KSELFTESTS_NEXT_URL=${KSELFTESTS_NEXT_URL}
KSELFTESTS_NEXT_VERSION=${KSELFTESTS_NEXT_VERSION}
LTP_URL=${LTP_URL}
LTP_VERSION=${LTP_VERSION}
LTP_REVISION=${LTP_REVISION}
LIBHUGETLBFS_URL=${LIBHUGETLBFS_URL}
LIBHUGETLBFS_VERSION=${LIBHUGETLBFS_VERSION}
LIBHUGETLBFS_REVISION=${LIBHUGETLBFS_REVISION}
MAKE_KERNELVERSION=${MAKE_KERNELVERSION}
TOOLCHAIN="${TARGET_SYS} ${GCCVERSION}"
KERNEL_ARGS="${KERNEL_ARGS}"
INITRD_URL="${INITRD_URL}"
OVMF="${BASE_URL}/${PUB_DEST}/${OVMF}"
CERTS="${BASE_URL}/${PUB_DEST}/${CERTS}"
FIRMWARE="${BASE_URL}/${PUB_DEST}/${FIRMWARE}"
EOF

cat ${WORKSPACE}/post_build_lava_parameters
