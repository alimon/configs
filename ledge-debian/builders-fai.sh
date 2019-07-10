#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
  cd ${WORKSPACE}
  sudo kpartx -dv /tmp/work.raw || true
  sudo umount -f /tmp||true
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

# speed up FAI
test -d builddir || mkdir builddir
sudo mount -t tmpfs -o size=6G tmpfs builddir

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
         builddir/work.raw

    sudo cp /var/log/fai/linaro-${rootfs}/last/fai.log fai-${rootfs}.log
    if grep -E '^(ERROR:|WARNING: These unknown packages are removed from the installation list|Exit code task_)' fai-${rootfs}.log
    then
        echo "Errors during build"
        rm -rf out/
        exit 1
    fi

    # snatch the rootfs and bootfs for lava
    for device in $(sudo kpartx -avs /tmp/work.raw | cut -d' ' -f3); do
        partition=$(echo ${device} | cut -d'p' -f3)
        sudo dd if=/dev/mapper/${device} of=/tmp/partition.raw bs=512
        if [ "${partition}" = "2" ]; then
            sudo mount -o loop /tmp/partition.raw /mnt
            #kvers=$(ls /mnt/boot/vmlinuz-*|sed -e 's,.*vmlinuz-,,'|sort -rV|head -1)
            #cp /mnt/boot/vmlinuz-${kvers} out/vmlinuz
            #cp /mnt/boot/initrd.img-${kvers}  out/initrd
            #cp /mnt/usr/lib/linux-image-$kvers/tih410-b2260.dtb out/
            sudo tar caf out/rootfs-${image_name}.tar /mnt
            sudo chroot /mnt dpkg -l > out/${image_name}.packages
            sudo umount -f /mnt
        fi
        sudo rm -f /tmp/partition.raw
    done
    sudo kpartx -dv /tmp/work.raw
    cp /tmp/work.raw out/${image_name}.sd

    # Compress image(s)
    pigz -9 out/rootfs-${image_name}.tar out/${image_name}.sd
done

