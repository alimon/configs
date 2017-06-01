#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
  cd ${WORKSPACE}
  sudo umount boot rootfs || true
  sudo kpartx -dv out/b2260-stretch_*.img || true
  sudo rm -rf boot rootfs || true
  rm -rf lci-build-tools
  rm -rf builddir*
  sudo git clean -fdx --exclude=out
}

#
# Pull required tooling into Docker container
#
sudo apt-get -q=2 update
sudo apt-get -q=2 install -y kpartx python-requests linaro-image-tools

export LANG=C
export make_bootwrapper=false
export make_install=true
export kernel_flavour=multi-v7
export use_config_fragment=1
export conf_filenames="arch/arm/configs/multi_v7_defconfig arch/arm/configs/bluetooth_6lowpan.conf"
export MAKE_DTBS=true
export tcbindir="${HOME}/srv/toolchain/arm-tc-16.02/bin"
export toolchain_url=http://releases.linaro.org/components/toolchain/binaries/5.3-2016.02/arm-linux-gnueabihf/gcc-linaro-5.3-2016.02-x86_64_arm-linux-gnueabihf.tar.xz

# Enable bluetooth 6lowpan
cat << EOF > arch/arm/configs/bluetooth_6lowpan.conf
CONFIG_6LOWPAN=m
CONFIG_6LOWPAN_DEBUGFS=y
CONFIG_IEEE802154=m
CONFIG_IEEE802154_NL802154_EXPERIMENTAL=y
CONFIG_IEEE802154_6LOWPAN=m
CONFIG_MAC802154=m
CONFIG_BT_BNEP=m
CONFIG_BT_BNEP_MC_FILTER=y
CONFIG_BT_BNEP_PROTO_FILTER=y
CONFIG_BT_6LOWPAN=m
CONFIG_IEEE802154_FAKELB=m
CONFIG_IEEE802154_AT86RF230=m
CONFIG_IEEE802154_AT86RF230_DEBUGFS=y
CONFIG_IEEE802154_MRF24J40=m
CONFIG_IEEE802154_CC2520=m
CONFIG_IEEE802154_ATUSB=m
EOF

rm -rf configs lci-build-tools
git clone --depth 1 http://git.linaro.org/ci/lci-build-tools.git
git clone --depth 1 http://git.linaro.org/ci/job/configs.git
wget -q http://builds.96boards.org/snapshots/b2260/linaro/u-boot/latest/u-boot.bin \
     -O configs/96boards-b2260/boot/b2260/u-boot.bin
bash -x lci-build-tools/jenkins_kernel_build_inst
rm -rf out/dtbs
cp -a linux-*.deb out/
cp -a configs/96boards-b2260/boot out/

mkimage -A arm -O linux -C none -T kernel -a 0x40080000 -e 0x40080000 -n Linux -d out/zImage out/uImage

#
# Create the hardware pack
#
cp -a configs/96boards-b2260/hwpacks/linaro-b2260 .

VERSION=$(date +%Y%m%d)-${BUILD_NUMBER}
linaro-hwpack-create --debug linaro-b2260 ${VERSION}
linaro-hwpack-replace -t `ls hwpack_linaro-b2260_*_armhf_supported.tar.gz` -p `ls linux-image-*-linaro-multi-v7_*.deb` -r linux-image -d -i
linaro-hwpack-replace -t `ls hwpack_linaro-b2260_*_armhf_supported.tar.gz` -p `ls linux-headers-*-linaro-multi-v7_*.deb` -r linux-headers -d -i

#
# Generate build information
#
cat > out/HEADER.textile << EOF

h4. 96boards STiH410 B2260 - CE Debian

Build description:
* Build URL: "${BUILD_URL}":${BUILD_URL}
* Kernel tree: "${GIT_URL}":${GIT_URL}
* Kernel branch: ${GIT_BRANCH}
* Kernel commit: "${GIT_COMMIT}":https://github.com/Linaro/rpk/commit/${GIT_COMMIT}
* Kernel config: multi_v7_defconfig
EOF

for rootfs in ${ROOTFS}; do
  # Get rootfs
  export ROOTFS_BUILD_NUMBER=`wget -q --no-check-certificate -O - https://ci.linaro.org/job/stretch-armhf-rootfs/label=docker-jessie-armhf,rootfs=${rootfs}/lastSuccessfulBuild/buildNumber`
  export ROOTFS_BUILD_TIMESTAMP=`wget -q --no-check-certificate -O - https://ci.linaro.org/job/stretch-armhf-rootfs/label=docker-jessie-armhf,rootfs=${rootfs}/lastSuccessfulBuild/buildTimestamp?format=yyyyMMdd`
  export ROOTFS_BUILD_URL="http://snapshots.linaro.org/debian/images/stretch/${rootfs}-armhf/${ROOTFS_BUILD_NUMBER}/linaro-stretch-${rootfs}-${ROOTFS_BUILD_TIMESTAMP}-${ROOTFS_BUILD_NUMBER}.tar.gz"
  wget --progress=dot -e dotbytes=2M ${ROOTFS_BUILD_URL}

  cat >> out/HEADER.textile << EOF
* Rootfs (${rootfs}): "${rootfs}":http://snapshots.linaro.org/debian/images/stretch/${rootfs}-armhf/${ROOTFS_BUILD_NUMBER}
EOF

  # Create pre-built image(s)
  linaro-media-create --dev fastmodel --output-directory ${WORKSPACE}/out --image-file b2260-stretch_${rootfs}_${VERSION}.img --image-size 2G --binary linaro-stretch-${rootfs}-${ROOTFS_BUILD_TIMESTAMP}-${ROOTFS_BUILD_NUMBER}.tar.gz --hwpack hwpack_linaro-b2260_*.tar.gz --hwpack-force-yes --bootloader uefi

  # Customize image(s)
  mkdir -p boot rootfs
  for device in $(sudo kpartx -avs out/b2260-stretch_${rootfs}_${VERSION}.img | cut -d' ' -f3); do
    partition=$(echo ${device} | cut -d'p' -f3)
    [ "${partition}" = "1" ] && sudo mount -o loop /dev/mapper/${device} boot
    [ "${partition}" = "2" ] && sudo mount -o loop /dev/mapper/${device} rootfs
  done

  sudo cp -a configs/96boards-b2260/boot/b2260 boot/ || true
  sudo cp -a configs/96boards-b2260/boot/update_default_boot.sh boot/ || true
  sudo cp -a out/uImage boot/ || true

  sudo rm -rf rootfs/dev rootfs/boot rootfs/var/lib/apt/lists
  sudo mkdir rootfs/dev rootfs/boot rootfs/var/lib/apt/lists

  sudo umount boot rootfs
  sudo kpartx -dv out/b2260-stretch_*.img

  # Compress image(s)
  gzip -9 out/b2260-stretch_${rootfs}_${VERSION}.img
done

# Create MD5SUMS file
find out -type f | xargs md5sum > MD5SUMS.txt
sed -i "s|out/||" MD5SUMS.txt
mv MD5SUMS.txt out
