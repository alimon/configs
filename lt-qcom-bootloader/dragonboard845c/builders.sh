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
      "*/15-tz/tz.mbn" \
      "*/40-qupv3fw/qupv3fw.elf"

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

# gcc toolchain
toolchain_url=http://releases.linaro.org/components/toolchain/binaries/6.3-2017.02/aarch64-linux-gnu/gcc-linaro-6.3.1-2017.02-x86_64_aarch64-linux-gnu.tar.xz
tcdir=${HOME}/srv/toolchain
tcbindir="${tcdir}/$(basename $toolchain_url .tar.xz)/bin"
export PATH=${tcbindir}:${PATH}

# Clang
git clone ${ABL_CLANG_GIT} --depth 1 -b ${ABL_CLANG_REL} ${WORKSPACE}/clang

# get and build abl
git clone --depth 1 ${ABL_GIT_LINARO} -b ${ABL_GIT_REL} abl
pushd abl
mkdir -p out/edk2
make all \
     BOOTLOADER_OUT=out/edk2 \
     BUILD_SYSTEM_ROOT_IMAGE=0 \
     VERIFIED_BOOT=0 \
     VERIFIED_BOOT_2=0 \
     VERIFIED_BOOT_LE=0 \
     USER_BUILD_VARIANT=0 \
     DISABLE_PARALLEL_DOWNLOAD_FLASH=1 \
     ABL_USE_SDLLVM=false \
     ABL_SAFESTACK=false \
     CLANG_BIN=${WORKSPACE}/clang/clang-4691093/bin/ \
     CLANG_PREFIX="aarch64-linux-gnu-" \
     CLANG_GCC_TOOLCHAIN=$(tcbindir)/aarch64-linux-gnu-gcc \
     TARGET_ARCHITECTURE=AARCH64 \
     BOARD_BOOTLOADER_PRODUCT_NAME="SuperEDK2k"

# get the signing tools, and sign
# add SSH server signatures to known_hosts list.
bash -c "ssh-keyscan dev-private-git.linaro.org >  ${HOME}/.ssh/known_hosts"
bash -c "ssh-keyscan dev-private-review.linaro.org >>  ${HOME}/.ssh/known_hosts"
git clone --depth 1 ssh://git@dev-private-git.linaro.org/landing-teams/working/qualcomm/sectools.git

python2 sectools/sectools.py secimage -v \
        -c sectools/config/sdm845/sdm845_secimage.xml \
        -g abl -i abl.elf -o out -sa
popd

# bootloader_ufs_linux
cp -a LICENSE \
   dragonboard845c/linux/flashall \
   bootloaders-linux/* \
   abl/out/sdm845/abl/abl.elf \
   out/${BOOTLOADER_UFS_LINUX}

# bootloader_ufs_aosp
cp -a LICENSE \
   dragonboard845c/aosp/flashall \
   bootloaders-linux/* \
   abl/out/sdm845/abl/abl.elf \
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
* "ABL source code":$ABL_GIT_LINARO/log/?h=$(echo $ABL_GIT_REL | sed -e 's/+/\%2b/g')
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
