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

export PATH=`pwd`/skales:$PATH
VERSION=$(cat build-version)

# Create boot image for SD boot
mkbootimg \
    --kernel out/Image \
    --ramdisk "out/initrd.img-$(cat kernel-version)" \
    --output out/boot-sdcard-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${VERSION}.img \
    --dt out/dt.img \
    --pagesize "${BOOTIMG_PAGESIZE}" \
    --base "0x80000000" \
    --cmdline "root=/dev/mmcblk1p9 rw rootwait console=${SERIAL_CONSOLE},115200n8"
gzip -9 out/boot-sdcard-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${VERSION}.img

git clone --depth 1 -b master https://git.linaro.org/landing-teams/working/qualcomm/db-boot-tools.git
# record commit info in build log
cd db-boot-tools
git log -1

# Get SD bootloader package
BL_BUILD_NUMBER=`wget -q --no-check-certificate -O - https://ci.linaro.org/jenkins/job/lt-qcom-bootloader-dragonboard410c/lastSuccessfulBuild/buildNumber`
wget --progress=dot -e dotbytes=2M \
     http://builds.96boards.org/snapshots/dragonboard410c/linaro/rescue/${BL_BUILD_NUMBER}/dragonboard410c_bootloader_sd_linux-${BL_BUILD_NUMBER}.zip

unzip -d out dragonboard410c_bootloader_sd_linux-${BL_BUILD_NUMBER}.zip
cp ${WORKSPACE}/out/boot-sdcard-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${VERSION}.img.gz out/boot.img.gz
gunzip out/boot.img.gz

for rootfs in ${SDCARD}; do
    sz=$(echo $rootfs | cut -f2 -d,)
    rootfs=$(echo $rootfs | cut -f1 -d,)

    rm -f out/rootfs.img out/rootfs.img.gz
    cp ${WORKSPACE}/out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.img.gz out/rootfs.img.gz
    gunzip out/rootfs.img.gz

    sudo ./mksdcard -p dragonboard410c/linux/sdcard.txt -s $sz -i out -o dragonboard410c_sdcard_${rootfs}_debian-${BUILD_NUMBER}.img

    # create archive for publishing
    zip -j ${WORKSPACE}/out/dragonboard410c_sdcard_${rootfs}_debian-${BUILD_NUMBER}.zip dragonboard410c_sdcard_${rootfs}_debian-${BUILD_NUMBER}.img out/LICENSE
done

cd ..
