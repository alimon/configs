#!/bin/bash

set -e

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="fai-server fai-setup-storage qemu-utils procps mtools pigz zip android-tools-fsutils android-tools-mkbootimg"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

set -ex

# Build information
mkdir -p out
cat > out/HEADER.textile << EOF

h4. QCOM Landing Team - $BUILD_DISPLAY_NAME

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* OS flavour: $OS_FLAVOUR
* FAI: "$GIT_URL":$GIT_URL
* FAI commit: "$GIT_COMMIT":$GIT_URL/commit/?id=$GIT_COMMIT
EOF

sudo mount -t tmpfs tmpfs /tmp

for rootfs in ${ROOTFS}; do

    rootfs_sz=$(echo $rootfs | cut -f2 -d,)
    rootfs=$(echo $rootfs | cut -f1 -d,)

    sudo fai-diskimage -v --cspace $(pwd) \
         --hostname linaro-${rootfs} \
         -S ${rootfs_sz} \
         --class $(echo SAVECACHE,${OS_FLAVOUR},DEBIAN,LINARO,QCOM,${rootfs},${FAI_BOARD_CLASS},RAW | tr '[:lower:]' '[:upper:]') \
         /tmp/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.raw

    cp /var/log/fai/linaro-${rootfs}/last/fai.log fai-${rootfs}.log
    if grep ^ERROR: fai-${rootfs}.log
    then
        echo "Errors during build"
        rm -rf out/
        exit 1
    fi

    rootfs_sz_real=$(du -h /tmp/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.raw | cut -f1)

    # make sure that there are the same for all images, in case we build more than 1 image
    if [ -f MD5SUM ]; then
        md5sum -c MD5SUM
    else
        md5sum out/{vmlinuz-*,config-*,$(basename ${DTBS})} > MD5SUM
    fi

    img2simg /tmp/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.raw out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.img
    sudo rm -f /tmp/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.raw

    # Compress image(s)
    pigz -9 out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.img

    # dpkg -l output
    mv out/packages.txt out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.packages

    cat >> out/HEADER.textile << EOF
* Linaro Debian ${rootfs}: size: ${rootfs_sz_real}
EOF
done

# Create boot image
cat out/vmlinuz-* out/$(basename ${DTBS}) > Image.gz+dtb
mkbootimg \
    --kernel Image.gz+dtb \
    --ramdisk out/initrd.img-* \
    --output out/boot-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${BUILD_NUMBER}.img \
    --pagesize "${BOOTIMG_PAGESIZE}" \
    --base "${BOOTIMG_BASE}" \
    --kernel_offset "${BOOTIMG_KERNEL_OFFSET}" \
    --ramdisk_offset "${BOOTIMG_RAMDISK_OFFSET}" \
    --tags_offset "${BOOTIMG_TAGS_OFFSET}" \
    --cmdline "root=/dev/disk/by-partlabel/${ROOTFS_PARTLABEL} rw rootwait console=tty0 console=${SERIAL_CONSOLE},115200n8"
pigz -9 out/boot-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${BUILD_NUMBER}.img
