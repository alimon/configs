#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    # cleanup here, only in case of error in this script
    # normal cleanup deferred to later
    [ $? = 0 ] && exit;
    cd ${WORKSPACE}
    sudo git clean -fdxq
}

# SDCard installer is only supported in dragonboard-410c
if [ -z "$SDCARD" ]; then
    exit 0
fi

# get ROOTFS from FAI config
ROOTFS_PARTLABEL=$(grep --color=never -Po  "^ROOTFS_PARTLABEL=\K.*" class/${FAI_BOARD_CLASS}.var)

# Create boot image for SD boot
KERNEL_CMDLINE="root=PARTLABEL=${ROOTFS_PARTLABEL} console=tty0 console=${SERIAL_CONSOLE},115200n8 ${KERNEL_CMDLINE_PLATFORM}"
mkbootimg \
    --kernel Image.gz+dtb \
    --ramdisk out/initrd.img-* \
    --output out/boot-sdcard-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${BUILD_NUMBER}.img \
    --pagesize "${BOOTIMG_PAGESIZE}" \
    --base "0x80000000" \
    --cmdline "${KERNEL_CMDLINE}"
gzip -9 out/boot-sdcard-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${BUILD_NUMBER}.img

rm -rf db-boot-tools
git clone --depth 1 -b master https://git.linaro.org/landing-teams/working/qualcomm/db-boot-tools.git
# record commit info in build log
cd db-boot-tools
git log -1

# Get SD bootloader package
BL_BUILD_NUMBER=`wget -q --no-check-certificate -O - https://ci.linaro.org/jenkins/job/lt-qcom-bootloader-dragonboard410c/lastSuccessfulBuild/buildNumber`
wget --progress=dot -e dotbytes=2M \
     http://snapshots.linaro.org/96boards/dragonboard410c/linaro/rescue/${BL_BUILD_NUMBER}/dragonboard-410c-bootloader-sd-linux-${BL_BUILD_NUMBER}.zip

unzip -jd out dragonboard-410c-bootloader-sd-linux-${BL_BUILD_NUMBER}.zip
cp ${WORKSPACE}/out/boot-sdcard-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.gz out/boot.img.gz
gunzip out/boot.img.gz

for rootfs in ${SDCARD}; do
    sz=$(echo $rootfs | cut -f2 -d,)
    rootfs=$(echo $rootfs | cut -f1 -d,)

    rm -f out/rootfs.img out/rootfs.img.gz
    cp ${WORKSPACE}/out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.gz out/rootfs.img.gz
    gunzip out/rootfs.img.gz

    SDCARD=${PLATFORM_NAME}-sdcard-${rootfs}-${OS_FLAVOUR}-${BUILD_NUMBER}
    mkdir -p ${SDCARD}
    sudo ./mksdcard -p dragonboard410c/linux/sdcard.txt -s $sz -i out -o ${SDCARD}/${SDCARD}.img

    # create archive for publishing
    cp out/LICENSE ${SDCARD}/
    zip -r ${WORKSPACE}/out/${SDCARD}.zip ${SDCARD}
done

cd ..
