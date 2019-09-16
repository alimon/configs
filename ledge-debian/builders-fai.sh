#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT
BUILDDIR="$WORKSPACE/builddir"
LOOPDEV='/dev/loop0'

cleanup_exit()
{
    cd ${WORKSPACE}
    sudo losetup -d "$LOOPDEV" || true
}

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="fai-server fai-setup-storage qemu-utils procps pigz kpartx u-boot-tools"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

set -ex

# Create version string
echo "$(date +%Y%m%d)-${BUILD_NUMBER}" > build-version

# Build information
mkdir -p out
cat > out/HEADER.textile << EOF

h4. Ledge - $BUILD_DISPLAY_NAME

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* OS flavour: $OS_FLAVOUR
* FAI: "$GIT_URL":$GIT_URL
* FAI commit: "$GIT_COMMIT":$GIT_URL/commit/?id=$GIT_COMMIT
EOF

# Don't use tmpfs to speedup FAI. armhf nodes only have 2GB of ram
test -d "$BUILDDIR" || mkdir -p "$BUILDDIR"

sudo cp tools/udevadm /sbin

for rootfs in ${ROOTFS}; do

    rootfs_sz=$(echo $rootfs | cut -f2 -d,)
    rootfs=$(echo $rootfs | cut -f1 -d,)
    VERSION=$(cat build-version)

    image_name=${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}

    # make bootable sd card
    sudo fai-diskimage -v --cspace $(pwd) \
         --hostname linaro-${rootfs} \
         -S ${rootfs_sz} \
         --class $(echo SAVECACHE,${OS_FLAVOUR},DEBIAN,LINARO,LEDGE,${rootfs} | tr '[:lower:]' '[:upper:]') \
         "$BUILDDIR"/work.raw

    sudo cp /var/log/fai/linaro-${rootfs}/last/fai.log fai-${rootfs}.log
    if grep -E '^(ERROR:|WARNING: These unknown packages are removed from the installation list|Exit code task_)' fai-${rootfs}.log
    then
        echo "Errors during build"
        rm -rf out/
        exit 1
    fi

    # extract content of raw image and put it on tarball
    LOOPDEV=$(sudo losetup -f -P --show ${BUILDDIR}/work.raw)
    sudo mount $LOOPDEV /mnt/
    cd /mnt/
    sudo tar cJf out/rootfs-${image_name}.tar.xz .
    cd -
    sudo umount /mnt
done

# specific for stm32mp157c-dk2 on arlmhf
ARMHF_ARCHITECTURE=$(echo ${PUB_DEST} | grep armhf | wc -l)
if [ $ARMHF_ARCHITECTURE -eq 1 ]
then
    # donwload flashlayout and script from github
    mkdir -p out/script
    wget https://raw.githubusercontent.com/Linaro/meta-ledge/thud/meta-ledge-bsp/recipes-devtools/generate-raw-image/raw-tools/create_raw_from_flashlayout.sh -O out/script/create_raw_from_flashlayout.sh
    wget https://raw.githubusercontent.com/Linaro/meta-ledge/thud/meta-ledge-bsp/recipes-devtools/generate-raw-image/files/ledge-stm32mp157c-dk2/FlashLayout_sdcard_ledge-stm32mp157c-dk2-debian.fld -O  out/FlashLayout_sdcard_ledge-stm32mp157c-dk2-debian.fld
    chmod +x out/script/create_raw_from_flashlayout.sh
fi
