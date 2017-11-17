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

# Create boot image for SD installer
mkbootimg \
    --kernel Image.gz+dtb \
    --ramdisk out/initrd.img-* \
    --output out/boot-installer-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${BUILD_NUMBER}.img \
    --pagesize "${BOOTIMG_PAGESIZE}" \
    --base "0x80000000" \
    --cmdline "root=/dev/mmcblk1p8 rw rootwait console=${SERIAL_CONSOLE},115200n8"
gzip -9 out/boot-installer-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${BUILD_NUMBER}.img

rm -rf db-boot-tools
git clone --depth 1 -b master https://git.linaro.org/landing-teams/working/qualcomm/db-boot-tools.git
# record commit info in build log
cd db-boot-tools
git log -1

# Get SD and EMMC bootloader package
BL_BUILD_NUMBER=`wget -q --no-check-certificate -O - https://ci.linaro.org/jenkins/job/lt-qcom-bootloader-dragonboard410c/lastSuccessfulBuild/buildNumber`
wget --progress=dot -e dotbytes=2M \
     http://builds.96boards.org/snapshots/dragonboard410c/linaro/rescue/${BL_BUILD_NUMBER}/dragonboard410c_bootloader_sd_linux-${BL_BUILD_NUMBER}.zip
wget --progress=dot -e dotbytes=2M \
     http://builds.96boards.org/snapshots/dragonboard410c/linaro/rescue/${BL_BUILD_NUMBER}/dragonboard410c_bootloader_emmc_linux-${BL_BUILD_NUMBER}.zip

unzip -d out dragonboard410c_bootloader_sd_linux-${BL_BUILD_NUMBER}.zip
cp ${WORKSPACE}/out/boot-installer-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.gz out/boot.img.gz
cp ${WORKSPACE}/out/${VENDOR}-${OS_FLAVOUR}-installer-${PLATFORM_NAME}-${BUILD_NUMBER}.img.gz out/rootfs.img.gz
gunzip out/{boot,rootfs}.img.gz

mkdir -p os/debian
cp ${WORKSPACE}/out/boot-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.gz os/debian/boot.img.gz
cp ${WORKSPACE}/out/${VENDOR}-${OS_FLAVOUR}-alip-${PLATFORM_NAME}-${BUILD_NUMBER}.img.gz os/debian/rootfs.img.gz
gunzip os/debian/{boot,rootfs}.img.gz

cat << EOF >> os/debian/os.json
{
"name": "Linaro Linux Desktop for DragonBoard 410c - Build #${BUILD_NUMBER}",
"url": "http://builds.96boards.org/releases/dragonboard410c",
"version": "${BUILD_NUMBER}",
"release_date": "`date +%Y-%m-%d`",
"description": "Linaro Linux with LXQt desktop based on Debian (${OS_FLAVOUR}) for DragonBoard 410c"
}
EOF

cp mksdcard flash os/
cp dragonboard410c/linux/partitions.txt os/debian
unzip -d os/debian dragonboard410c_bootloader_emmc_linux-${BL_BUILD_NUMBER}.zip

# get size of OS partition
size_os=$(du -sk os | cut -f1)
size_os=$(((($size_os + 1024 - 1) / 1024) * 1024))
size_os=$(($size_os + 200*1024))
# pad for SD image size (including rootfs and bootloaders)
size_img=$(($size_os + 1024*1024 + 300*1024))

# create OS image
SDCARD=${PLATFORM_NAME}-sdcard-installer-${OS_FLAVOUR}-${BUILD_NUMBER}
mkdir -p ${SDCARD}

sudo rm -f out/os.img
sudo mkfs.fat -a -F32 -n "OS" -C out/os.img $size_os
mkdir -p mnt
sudo mount -o loop out/os.img mnt
sudo cp -r os/* mnt/
sudo umount mnt
sudo ./mksdcard -p dragonboard410c/linux/installer.txt -s $size_img -i out -o ${SDCARD}/${SDCARD}.img

# create archive for publishing
cp out/LICENSE ${SDCARD}/
zip -r ${WORKSPACE}/out/${SDCARD}.zip ${SDCARD}
cd ..
