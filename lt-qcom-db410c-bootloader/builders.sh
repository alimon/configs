#!/bin/bash
set -ex

sudo apt-get update
sudo apt-get install -y zip gdisk

# download the firmware packages
wget -q ${QCOM_LINUX_FIRMWARE}
wget -q ${QCOM_ANDROID_FIRMWARE}
wget -q ${QCOM_ANDROID_FIRMWARE_OLD}
echo "${QCOM_LINUX_FIRMWARE_MD5}  $(basename ${QCOM_LINUX_FIRMWARE})" > MD5
echo "${QCOM_ANDROID_FIRMWARE_MD5}  $(basename ${QCOM_ANDROID_FIRMWARE})" >> MD5
echo "${QCOM_ANDROID_FIRMWARE_OLD_MD5}  $(basename ${QCOM_ANDROID_FIRMWARE_OLD})" >> MD5
md5sum -c MD5

unzip -j -d bootloaders-android $(basename ${QCOM_ANDROID_FIRMWARE})
unzip -j -d bootloaders-android-old $(basename ${QCOM_ANDROID_FIRMWARE_OLD})
unzip -j -d bootloaders-linux $(basename ${QCOM_LINUX_FIRMWARE}) "*/bootloaders-linux/*"

# Get the Android compiler
git clone ${LK_GCC_GIT} --depth 1 -b ${LK_GCC_REL} android-gcc

# Build all needed flavors of LK
git clone --depth 1 ${LK_GIT_LINARO} -b ${LK_GIT_REL_SD_RESCUE} lk_sdrescue
git clone --depth 1 ${LK_GIT_LINARO} -b ${LK_GIT_REL_SD_BOOT} lk_sd_boot
git clone --depth 1 ${LK_GIT_LINARO} -b ${LK_GIT_REL_EMMC_BOOT} lk_emmc_boot

for lk in lk_sdrescue lk_sd_boot lk_emmc_boot; do
    echo "Building LK in : $lk"
    cd $lk
    git log -1
    make -j4 msm8916 EMMC_BOOT=1 TOOLCHAIN_PREFIX=${WORKSPACE}/android-gcc/bin/arm-eabi-
    cd -
done

mkdir -p out/dragonboard410c_sdcard_rescue \
      out/dragonboard410c_bootloader_sd_linux \
      out/dragonboard410c_bootloader_emmc_linux \
      out/dragonboard410c_bootloader_emmc_android

# get license.txt file
wget https://git.linaro.org/landing-teams/working/qualcomm/lt-docs.git/blob_plain/HEAD:/license/license.txt

# bootloader_emmc_linux
cp -a license.txt \
   dragonboard410c/linux/flashall \
   lk_emmc_boot/build-msm8916/emmc_appsboot.mbn \
   bootloaders-linux/{NON-HLOS.bin,rpm.mbn,sbl1.mbn,tz.mbn,tz-psci.mbn,hyp.mbn} \
   out/dragonboard410c_bootloader_emmc_linux

# no need to set the eMMC size here. Fastboot will patch the last partition and grow it until last sector
sudo ./mksdcard -x -g -o gpt.img -p dragonboard410c/linux/partitions.txt
sudo sgdisk -bgpt.bin gpt.img
./mkgpt -d -i gpt.bin -o out/dragonboard410c_bootloader_emmc_linux/gpt_both0.bin

# bootloader_emmc_android
cp -a license.txt \
   dragonboard410c/android/flashall \
   dragonboard410c/android/emmc_appsboot.mbn \
   bootloaders-android-old/sbl1.mbn \
   bootloaders-android/{NON-HLOS.bin,rpm.mbn,tz.mbn,hyp.mbn} \
   out/dragonboard410c_bootloader_emmc_android

# no need to set the eMMC size here. Fastboot will patch the last partition and grow it until last sector
sudo ./mksdcard -x -g -o gpt.img -p dragonboard410c/android/partitions.txt
sudo sgdisk -bgpt.bin gpt.img
./mkgpt -d -i gpt.bin -o out/dragonboard410c_bootloader_emmc_android/gpt_both0.bin

# bootloader_sd_linux
cp -a license.txt \
   lk_sd_boot/build-msm8916/emmc_appsboot.mbn \
   bootloaders-linux/{NON-HLOS.bin,rpm.mbn,sbl1.mbn,tz.mbn,tz-psci.mbn,hyp.mbn} \
   out/dragonboard410c_bootloader_sd_linux

# sdcard_rescue
cp -a license.txt out/dragonboard410c_sdcard_rescue
sudo ./mksdcard -x -p dragonboard410c/linux/sdrescue.txt \
     -o out/dragonboard410c_sdcard_rescue/db410c_sd_rescue.img \
     -i lk_sdrescue/build-msm8916/ \
     -i bootloaders-linux/

# Create MD5SUMS file
for i in dragonboard410c_sdcard_rescue dragonboard410c_bootloader_sd_linux \
                                       dragonboard410c_bootloader_emmc_linux dragonboard410c_bootloader_emmc_android; do
    (cd out/$i && md5sum * > MD5SUMS.txt)
done

# Final preparation of archives for publishing
mkdir out2
zip -rj out2/dragonboard410c_sdcard_rescue-${BUILD_NUMBER}.zip out/dragonboard410c_sdcard_rescue
zip -rj out2/dragonboard410c_bootloader_emmc_linux-${BUILD_NUMBER}.zip out/dragonboard410c_bootloader_emmc_linux
zip -rj out2/dragonboard410c_bootloader_emmc_android-${BUILD_NUMBER}.zip out/dragonboard410c_bootloader_emmc_android
zip -rj out2/dragonboard410c_bootloader_sd_linux-${BUILD_NUMBER}.zip out/dragonboard410c_bootloader_sd_linux

# Create MD5SUMS file
(cd out2 && md5sum * > MD5SUMS.txt)

# Build information
cat > out2/HEADER.textile << EOF

h4. Bootloaders for Dragonboard 410c

This page provides the bootloaders packages for the Dragonboard 410c. There are several packages:
* *sdcard_rescue* : an SD card image that can be used to boot from SD card, and rescue a board when the onboard eMMC is empty or corrupted
* *bootloader_emmc_linux* : includes the bootloaders and partition table (GPT) used when booting Linux images from onboard eMMC
* *bootloader_emmc_android* : includes the bootloaders and partition table (GPT) used when booting Android images from onboard eMMC
* *bootloader_sd_linux* : includes the bootloaders and partition table (GPT) used when booting Linux images from SD card

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Proprietary bootloaders can be found on "Qualcomm Developer Network":https://developer.qualcomm.com/hardware/dragonboard-410c/tools
* Android proprietary bootloaders package: $(basename ${QCOM_ANDROID_FIRMWARE})
* Linux proprietary bootloaders package: $(basename ${QCOM_LINUX_FIRMWARE})
* Little Kernel (LK) source code:
** "SD rescue boot":$LK_GIT_LINARO/shortlog/refs/heads/$LK_GIT_REL_SD_RESCUE
** "SD Linux boot":$LK_GIT_LINARO/shortlog/refs/heads/$LK_GIT_REL_SD_BOOT
** "eMMC Linux boot":$LK_GIT_LINARO/shortlog/refs/heads/$LK_GIT_REL_EMMC_BOOT
* Tools version: "$GIT_COMMIT":$GIT_URL/commit/$GIT_COMMIT
EOF

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
     --server ${PUBLISH_SERVER} \
     --link-latest \
     out2 snapshots/dragonboard410c/linaro/rescue/${BUILD_NUMBER}
