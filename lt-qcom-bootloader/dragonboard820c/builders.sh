#!/bin/bash

sudo apt-get update
sudo apt-get install -y zip gdisk

set -ex

# download the firmware packages
wget -q ${QCOM_LINUX_FIRMWARE}
echo "${QCOM_LINUX_FIRMWARE_MD5}  $(basename ${QCOM_LINUX_FIRMWARE})" > MD5
md5sum -c MD5

unzip -j -d bootloaders-linux $(basename ${QCOM_LINUX_FIRMWARE}) "*/bootloaders-linux/*" "*/cdt-linux/*" "*/loaders/*"

# Get the Android compiler
git clone ${LK_GCC_GIT} --depth 1 -b ${LK_GCC_REL} android-gcc

# get the signing tools
git clone --depth 1 https://git.linaro.org/landing-teams/working/qualcomm/signlk.git

# Build all needed flavors of LK
git clone --depth 1 ${LK_GIT_LINARO} -b ${LK_GIT_REL_SD_RESCUE} lk_sdrescue
git clone --depth 1 ${LK_GIT_LINARO} -b ${LK_GIT_REL_UFS_BOOT} lk_ufs_boot

for lk in lk_sdrescue lk_ufs_boot; do
    echo "Building LK in : $lk"
    cd $lk
    git log -1
    make -j4 msm8996 EMMC_BOOT=1 VERIFIED_BOOT=1 TOOLCHAIN_PREFIX=${WORKSPACE}/android-gcc/bin/arm-eabi-
    mv build-msm8996/emmc_appsboot.mbn build-msm8996/emmc_appsboot_unsigned.mbn
    ../signlk/signlk.sh -i=./build-msm8996/emmc_appsboot_unsigned.mbn -o=./build-msm8996/emmc_appsboot.mbn -d
    cd -
done

SDCARD_RESCUE=dragonboard-820c-sdcard-rescue-${BUILD_NUMBER}
BOOTLOADER_UFS_LINUX=dragonboard-820c-bootloader-ufs-linux-${BUILD_NUMBER}
BOOTLOADER_UFS_AOSP=dragonboard-820c-bootloader-ufs-aosp-${BUILD_NUMBER}

mkdir -p out/${SDCARD_RESCUE} out/${BOOTLOADER_UFS_LINUX} out/${BOOTLOADER_UFS_AOSP}

# get LICENSE file (for Linux BSP)
unzip -j $(basename ${QCOM_LINUX_FIRMWARE}) "*/LICENSE"
echo "${QCOM_LINUX_FIRMWARE_LICENSE_MD5}  LICENSE" > MD5
md5sum -c MD5

# bootloader_ufs_linux
cp -a LICENSE \
   dragonboard820c/linux/flashall \
   lk_ufs_boot/build-msm8996/emmc_appsboot.mbn \
   bootloaders-linux/{cmnlib64.mbn,cmnlib.mbn,devcfg.mbn,hyp.mbn,keymaster.mbn,pmic.elf,rpm.mbn,sbc_1.0_8096.bin,tz.mbn,xbl.elf} \
   bootloaders-linux/prog_ufs_firehose_8996_ddr.elf \
   dragonboard820c/linux/{rawprogram,patch}.xml \
   dragonboard820c/linux/gpt_*.bin \
   dragonboard820c/linux/zeros_*.bin \
   dragonboard820c/ufs-provision_toshiba.xml \
   out/${BOOTLOADER_UFS_LINUX}

# bootloader_ufs_aosp
cp -a LICENSE \
   dragonboard820c/aosp/flashall \
   lk_ufs_boot/build-msm8996/emmc_appsboot.mbn \
   bootloaders-linux/{cmnlib64.mbn,cmnlib.mbn,devcfg.mbn,hyp.mbn,keymaster.mbn,pmic.elf,rpm.mbn,sbc_1.0_8096.bin,tz.mbn,xbl.elf} \
   bootloaders-linux/prog_ufs_firehose_8996_ddr.elf \
   dragonboard820c/aosp/{rawprogram,patch}.xml \
   dragonboard820c/aosp/gpt_*.bin \
   dragonboard820c/aosp/zeros_*.bin \
   dragonboard820c/ufs-provision_toshiba.xml \
   out/${BOOTLOADER_UFS_AOSP}

# sdcard_rescue
cp -a LICENSE out/${SDCARD_RESCUE}
sudo ./mksdcard -x -p dragonboard820c/sdrescue.txt \
     -o out/${SDCARD_RESCUE}/${SDCARD_RESCUE}.img \
     -i lk_sdrescue/build-msm8996/ \
     -i bootloaders-sdboot/ \
     -i bootloaders-linux/

# Final preparation of archives for publishing
mkdir ${WORKSPACE}/out2
for i in ${SDCARD_RESCUE} \
         ${BOOTLOADER_UFS_LINUX} \
         ${BOOTLOADER_UFS_AOSP} ; do
    (cd out/$i && md5sum * > MD5SUMS.txt)
    (cd out && zip -r ${WORKSPACE}/out2/$i.zip $i)
done

# Create MD5SUMS file
(cd ${WORKSPACE}/out2 && md5sum * > MD5SUMS.txt)

# Build information
cat > ${WORKSPACE}/out2/HEADER.textile << EOF

h4. Bootloaders for Dragonboard 820c

This page provides the bootloaders packages for the Dragonboard 820c. There are several packages:
* *sdcard_rescue* : an SD card image that can be used to boot from SD card, and rescue a board when the onboard UFS is empty or corrupted
* *bootloader_ufs_linux* : includes the bootloaders and partition table (GPT) used when booting Linux images from onboard UFS
* *bootloader_ufs_aosp* : includes the bootloaders and partition table (GPT) used when booting AOSP images from onboard UFS

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Proprietary bootloaders are not published yet, and not available widely
* Linux proprietary bootloaders package: $(basename ${QCOM_LINUX_FIRMWARE})
* Little Kernel (LK) source code:
** "SD rescue boot":$LK_GIT_LINARO/log/?h=$(echo $LK_GIT_REL_SD_RESCUE | sed -e 's/+/\%2b/g')
** "UFS Linux boot":$LK_GIT_LINARO/log/?h=$(echo $LK_GIT_REL_UFS_BOOT | sed -e 's/+/\%2b/g')
* Tools version: "$GIT_COMMIT":$GIT_URL/commit/?id=$GIT_COMMIT
EOF

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
     --server ${PUBLISH_SERVER} \
     --link-latest \
     ${WORKSPACE}/out2 ${PUB_DEST}
