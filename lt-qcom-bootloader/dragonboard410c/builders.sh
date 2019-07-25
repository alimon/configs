#!/bin/bash
set -ex

sudo apt-get update
sudo apt-get install -y zip gdisk

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
git clone --depth 1 ${LK_GIT_LINARO} -b ${LK_GIT_REL_SD_BOOT} lk_sd_boot
git clone --depth 1 ${LK_GIT_LINARO} -b ${LK_GIT_REL_EMMC_BOOT} lk_emmc_boot

for lk in lk_sdrescue lk_sd_boot lk_emmc_boot; do
    echo "Building LK in : $lk"
    cd $lk
    git log -1
    make -j4 msm8916 EMMC_BOOT=1 TOOLCHAIN_PREFIX=${WORKSPACE}/android-gcc/bin/arm-eabi-
    mv build-msm8916/emmc_appsboot.mbn build-msm8916/emmc_appsboot_unsigned.mbn
    ../signlk/signlk.sh -i=./build-msm8916/emmc_appsboot_unsigned.mbn -o=./build-msm8916/emmc_appsboot.mbn -d
    cd -
done

SDCARD_RESCUE=dragonboard-410c-sdcard-rescue-${BUILD_NUMBER}
BOOTLOADER_SD_LINUX=dragonboard-410c-bootloader-sd-linux-${BUILD_NUMBER}
BOOTLOADER_EMMC_LINUX=dragonboard-410c-bootloader-emmc-linux-${BUILD_NUMBER}
BOOTLOADER_EMMC_AOSP=dragonboard-410c-bootloader-emmc-aosp-${BUILD_NUMBER}

mkdir -p out/${SDCARD_RESCUE} \
      out/${BOOTLOADER_SD_LINUX} \
      out/${BOOTLOADER_EMMC_LINUX} \
      out/${BOOTLOADER_EMMC_AOSP}

# get LICENSE file (for Linux BSP)
unzip -j $(basename ${QCOM_LINUX_FIRMWARE}) "*/LICENSE"
echo "${QCOM_LINUX_FIRMWARE_LICENSE_MD5}  LICENSE" > MD5
md5sum -c MD5

# Create ptable and rawprogram/patch command files
git clone --depth 1 https://git.linaro.org/landing-teams/working/qualcomm/partioning_tool.git ptool
(cd ptool && git log -1)
(mkdir ptool/linux && cd ptool/linux && python2 ${WORKSPACE}/ptool/ptool.py -x ${WORKSPACE}/dragonboard410c/linux/partition.xml)
(mkdir ptool/aosp && cd ptool/aosp && python2 ${WORKSPACE}/ptool/ptool.py -x ${WORKSPACE}/dragonboard410c/aosp/partition.xml)

# bootloader_emmc_linux
cp -a LICENSE \
   dragonboard410c/linux/flashall \
   lk_emmc_boot/build-msm8916/emmc_appsboot.mbn \
   bootloaders-linux/prog_emmc_firehose_8916.mbn \
   bootloaders-linux/{NON-HLOS.bin,rpm.mbn,sbl1.mbn,tz.mbn,hyp.mbn,sbc_1.0_8016.bin} \
   ptool/linux/{rawprogram,patch}?.xml \
   ptool/linux/gpt_{main,backup,both}?.bin \
   ptool/linux/zeros_*.bin \
   out/${BOOTLOADER_EMMC_LINUX}

# bootloader_emmc_aosp
cp -a LICENSE \
   dragonboard410c/aosp/flashall \
   lk_emmc_boot/build-msm8916/emmc_appsboot.mbn \
   bootloaders-linux/{NON-HLOS.bin,rpm.mbn,sbl1.mbn,tz.mbn,hyp.mbn,sbc_1.0_8016.bin} \
   ptool/aosp/{rawprogram,patch}?.xml \
   ptool/aosp/gpt_{main,backup,both}?.bin \
   ptool/aosp/zeros_*.bin \
   out/${BOOTLOADER_EMMC_AOSP}

# bootloader_sd_linux
cp -a LICENSE \
   lk_sd_boot/build-msm8916/emmc_appsboot.mbn \
   bootloaders-linux/{NON-HLOS.bin,rpm.mbn,sbl1.mbn,tz.mbn,hyp.mbn,sbc_1.0_8016.bin} \
   out/${BOOTLOADER_SD_LINUX}

# sdcard_rescue
cp -a LICENSE out/${SDCARD_RESCUE}
sudo ./mksdcard -x -p dragonboard410c/linux/sdrescue.txt \
     -o out/${SDCARD_RESCUE}/${SDCARD_RESCUE}.img \
     -i lk_sdrescue/build-msm8916/ \
     -i out/${BOOTLOADER_SD_LINUX}

# Final preparation of archives for publishing
mkdir ${WORKSPACE}/out2
for i in ${SDCARD_RESCUE} \
         ${BOOTLOADER_SD_LINUX} \
         ${BOOTLOADER_EMMC_LINUX} \
         ${BOOTLOADER_EMMC_AOSP} ; do
    (cd out/$i && md5sum * > MD5SUMS.txt)
    (cd out && zip -r ${WORKSPACE}/out2/$i.zip $i)
done

# Create MD5SUMS file
(cd ${WORKSPACE}/out2 && md5sum * > MD5SUMS.txt)

# Build information
cat > ${WORKSPACE}/out2/HEADER.textile << EOF

h4. Bootloaders for Dragonboard 410c

This page provides the bootloaders packages for the Dragonboard 410c. There are several packages:
* *sdcard_rescue* : an SD card image that can be used to boot from SD card, and rescue a board when the onboard eMMC is empty or corrupted
* *bootloader-emmc-linux* : includes the bootloaders and partition table (GPT) used when booting Linux images from onboard eMMC
* *bootloader-emmc-aosp* : includes the bootloaders and partition table (GPT) used when booting AOSP based images from onboard eMMC
* *bootloader-sd-linux* : includes the bootloaders and partition table (GPT) used when booting Linux images from SD card

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Proprietary bootloaders can be found on "Qualcomm Developer Network":https://developer.qualcomm.com/hardware/dragonboard-410c/tools
* Linux proprietary bootloaders package: $(basename ${QCOM_LINUX_FIRMWARE})
* Little Kernel (LK) source code:
** "SD rescue boot":$LK_GIT_LINARO/log/?h=$(echo $LK_GIT_REL_SD_RESCUE  | sed -e 's/+/\%2b/g')
** "SD Linux boot":$LK_GIT_LINARO/log/?h=$(echo $LK_GIT_REL_SD_BOOT | sed -e 's/+/\%2b/g')
** "eMMC Linux boot":$LK_GIT_LINARO/log/?h=$(echo $LK_GIT_REL_EMMC_BOOT | sed -e 's/+/\%2b/g')
* Tools version: "$GIT_COMMIT":$GIT_URL/commit/?id=$GIT_COMMIT
* Partition table:
** "Linux":$GIT_URL/tree/dragonboard410c/linux/partition.xml?id=$GIT_COMMIT
** "AOSP":$GIT_URL/tree/dragonboard410c/aosp/partition.xml?id=$GIT_COMMIT
EOF

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
     --server ${PUBLISH_SERVER} \
     --link-latest \
     ${WORKSPACE}/out2 ${PUB_DEST}
