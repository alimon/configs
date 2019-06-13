#!/bin/bash

sudo apt-get update
sudo apt-get install -y zip gdisk

set -ex

# download the firmware packages
wget -q ${QCOM_LINUX_FIRMWARE}
echo "${QCOM_LINUX_FIRMWARE_MD5}  $(basename ${QCOM_LINUX_FIRMWARE})" > MD5
md5sum -c MD5

unzip -j -d bootloaders-linux $(basename ${QCOM_LINUX_FIRMWARE}) \
      "*/00-gpt/gpt_*" \
      "*/01-firehose_xml/patch*.xml" \
      "*/01-firehose_xml/rawprogram?.xml" \
      "*/02-firehose_prog/prog_firehose_ddr.elf" \
      "*/04-aop/aop.mbn" \
      "*/05-BTFM/BTFM.bin" \
      "*/06-cmnlib/cmnlib*" \
      "*/07-devcfg/devcfg.mbn" \
      "*/08-dspso/dspso.bin" \
      "*/09-hyp/hyp.mbn" \
      "*/10-imagefv/imagefv.elf" \
      "*/11-keymaster/keymaster64.mbn" \
      "*/13-sec/sec.dat" \
      "*/14-storsec/storsec.mbn" \
      "*/15-tz/tz.mbn"

BOOTLOADER_UFS_LINUX=dragonboard-845c-bootloader-ufs-linux-${BUILD_NUMBER}
BOOTLOADER_UFS_AOSP=dragonboard-845c-bootloader-ufs-aosp-${BUILD_NUMBER}

mkdir -p out/${BOOTLOADER_UFS_LINUX} out/${BOOTLOADER_UFS_AOSP}

# get LICENSE file (for Linux BSP)
unzip -j $(basename ${QCOM_LINUX_FIRMWARE}) "*/LICENSE.qcom.txt"
mv LICENSE.qcom.txt LICENSE
echo "${QCOM_LINUX_FIRMWARE_LICENSE_MD5}  LICENSE" > MD5
md5sum -c MD5

# process rawprogram commands files
sed -i \
    -e '/sda845-persist.ext4/d' \
    -e '/sda845-sysfs.ext4/d' \
    -e '/sda845-systemrw.ext4/d' \
    -e '/sda845-cache.ext4/d' \
    -e '/sda845-usrfs.ext4/d' \
    -e '/sda845-boot.img/d' \
    -e '/NON-HLOS.bin/d' \
    bootloaders-linux/rawprogram*.xml

# bootloader_ufs_linux
cp -a LICENSE \
   dragonboard845c/linux/flashall \
   bootloaders-linux/* \
   out/${BOOTLOADER_UFS_LINUX}

# bootloader_ufs_aosp
cp -a LICENSE \
   dragonboard845c/aosp/flashall \
   bootloaders-linux/* \
   out/${BOOTLOADER_UFS_AOSP}

# Final preparation of archives for publishing
mkdir ${WORKSPACE}/out2
for i in ${BOOTLOADER_UFS_LINUX} \
         ${BOOTLOADER_UFS_AOSP} ; do
    (cd out/$i && md5sum * > MD5SUMS.txt)
    (cd out && zip -r ${WORKSPACE}/out2/$i.zip $i)
done

# Create MD5SUMS file
(cd ${WORKSPACE}/out2 && md5sum * > MD5SUMS.txt)

# Build information
cat > ${WORKSPACE}/out2/HEADER.textile << EOF

h4. Bootloaders for Dragonboard 845c

This page provides the bootloaders packages for the Dragonboard 845c. There are several packages:
* *bootloader_ufs_linux* : includes the bootloaders and partition table (GPT) used when booting Linux images from onboard UFS
* *bootloader_ufs_aosp* : includes the bootloaders and partition table (GPT) used when booting AOSP images from onboard UFS

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Linux proprietary bootloaders package: $(basename ${QCOM_LINUX_FIRMWARE})
EOF

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
wget -q https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/lt-qcom-bootloader/dragonboard845c/build-info.txt -O BUILD-INFO.txt
time python ${HOME}/bin/linaro-cp.py \
     --server ${PUBLISH_SERVER} \
     --build-info BUILD-INFO.txt \
     --link-latest \
     ${WORKSPACE}/out2 ${PUB_DEST}
