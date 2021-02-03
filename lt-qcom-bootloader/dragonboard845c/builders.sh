#!/bin/bash

sudo apt-get update
sudo apt-get install -y zip gdisk libncurses5

set -ex

if [ -z "${WORKSPACE}" ]; then
	WORKSPACE="$(pwd)"
	DB_BOOT_TOOLS_DIR="db-boot-tools"

	if [ ! -d "${WORKSPACE}/${DB_BOOT_TOOLS_DIR}" ]; then
		git clone "${DB_BOOT_TOOLS_GIT}" "${WORKSPACE}/${DB_BOOT_TOOLS_DIR}"
	fi
else
	DB_BOOT_TOOLS_DIR="."
	LINARO_PUBLISH="True"
fi

# download the firmware packages
wget -c -q ${QCOM_LINUX_FIRMWARE}
echo "${QCOM_LINUX_FIRMWARE_MD5}  $(basename ${QCOM_LINUX_FIRMWARE})" > MD5
md5sum -c MD5

unzip -j -d bootloaders-linux $(basename ${QCOM_LINUX_FIRMWARE}) \
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
      "*/16-xbl/xbl.elf" \
      "*/16-xbl/xbl_config.elf" \
      "*/40-qupv3fw/qupv3fw.elf"

BOOTLOADER_UFS_LINUX=dragonboard-845c-bootloader-ufs-linux-${BUILD_NUMBER}
BOOTLOADER_UFS_AOSP=dragonboard-845c-bootloader-ufs-aosp-${BUILD_NUMBER}

mkdir -p out/${BOOTLOADER_UFS_LINUX} out/${BOOTLOADER_UFS_AOSP}

# get LICENSE file (for Linux BSP)
unzip -j $(basename ${QCOM_LINUX_FIRMWARE}) "*/LICENSE.qcom.txt"
mv LICENSE.qcom.txt LICENSE
echo "${QCOM_LINUX_FIRMWARE_LICENSE_MD5}  LICENSE" > MD5
md5sum -c MD5

# Create ptable and rawprogram/patch command files
if [ ! -d "ptool" ]; then
	git clone --depth 1 https://git.linaro.org/landing-teams/working/qualcomm/partioning_tool.git ptool
fi
(cd ptool && git log -1)
(mkdir -p ptool/linux && cd ptool/linux && python2 ${WORKSPACE}/ptool/ptool.py -x ${WORKSPACE}/${DB_BOOT_TOOLS_DIR}/dragonboard845c/linux/partition.xml)
(mkdir -p ptool/aosp && cd ptool/aosp && python2 ${WORKSPACE}/ptool/ptool.py -x ${WORKSPACE}/${DB_BOOT_TOOLS_DIR}/dragonboard845c/aosp/partition.xml)

# tcbindir from install-gcc-toolchain.sh
export PATH=${tcbindir}:$PATH

# Clang
if [ ! -d "${WORKSPACE}/clang" ]; then
	git clone ${ABL_CLANG_GIT} --depth 1 -b ${ABL_CLANG_REL} ${WORKSPACE}/clang
fi

# get and build abl
if [ ! -d "abl" ]; then
	git clone --depth 1 ${ABL_GIT_LINARO} -b ${ABL_GIT_REL} abl
fi
pushd abl
ABL_GIT_COMMIT=$(git rev-parse HEAD)
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
     AB_RETRYCOUNT_DISABLE=1 \
     CLANG_BIN=${WORKSPACE}/clang/clang-4691093/bin/ \
     CLANG_PREFIX="aarch64-none-linux-gnu-" \
     CLANG_GCC_TOOLCHAIN="${tcbindir}/aarch64-none-linux-gnu-gcc" \
     TARGET_ARCHITECTURE=AARCH64 \
     BOARD_BOOTLOADER_PRODUCT_NAME="SuperEDK2k"

# get the signing tools, and sign
# add SSH server signatures to known_hosts list.
bash -c "ssh-keyscan dev-private-git.linaro.org >>  ${HOME}/.ssh/known_hosts"
bash -c "ssh-keyscan dev-private-review.linaro.org >>  ${HOME}/.ssh/known_hosts"
if [ ! -d "sectools" ]; then
	git clone --depth 1 ssh://git@dev-private-git.linaro.org/landing-teams/working/qualcomm/sectools.git
fi

python2 sectools/sectools.py secimage -v \
        -c sectools/config/sdm845/sdm845_secimage.xml \
        -g abl -i abl.elf -o out -sa
popd

# Empty/zero boot image file to clear boot partition
dd if=/dev/zero of=boot-erase.img bs=1024 count=1024

# bootloader_ufs_linux
cp -a LICENSE \
   ${DB_BOOT_TOOLS_DIR}/dragonboard845c/linux/flashall \
   bootloaders-linux/* \
   abl/out/sdm845/abl/abl.elf \
   ptool/linux/{rawprogram?.xml,patch?.xml,gpt_main?.bin,gpt_backup?.bin,gpt_both?.bin} \
   boot-erase.img \
   out/${BOOTLOADER_UFS_LINUX}

# bootloader_ufs_aosp
cp -a LICENSE \
   ${DB_BOOT_TOOLS_DIR}/dragonboard845c/aosp/flashall \
   bootloaders-linux/* \
   abl/out/sdm845/abl/abl.elf \
   ptool/aosp/{rawprogram?.xml,patch?.xml,gpt_main?.bin,gpt_backup?.bin,gpt_both?.bin} \
   boot-erase.img \
   out/${BOOTLOADER_UFS_AOSP}

# Final preparation of archives for publishing
mkdir -p ${WORKSPACE}/out2
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
* "ABL source code":$ABL_GIT_LINARO/commit/?id=$ABL_GIT_COMMIT
* Partition table:
** "Linux":$GIT_URL/tree/dragonboard845c/linux/partition.xml?id=$GIT_COMMIT
** "AOSP":$GIT_URL/tree/dragonboard845c/aosp/partition.xml?id=$GIT_COMMIT
EOF

# Publish
if [ "${LINARO_PUBLISH}" ]; then
	test -d ${HOME}/bin || mkdir ${HOME}/bin
	wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
	time python3 ${HOME}/bin/linaro-cp.py \
	     --server ${PUBLISH_SERVER} \
	     --link-latest \
	     ${WORKSPACE}/out2 ${PUB_DEST}
fi
