#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    # cleanup here, only in case of error in this script
    # normal cleanup deferred to later
    [ $? = 0 ] && exit;
    cd ${WORKSPACE}
    sudo umount rootfs rootfs2 || true
    sudo kpartx -dv out/${VENDOR}-${OS_FLAVOUR}-*.sd.img || true
    sudo rm -rf rootfs rootfs2 || true
    sudo git clean -fdxq
}

sudo apt-get update
sudo apt-get install -y kpartx python-requests device-tree-compiler zip libfdt-dev mtools android-tools-fsutils linaro-image-tools

# get the boot image tools, and keep track of commit info in the traces
git clone git://codeaurora.org/quic/kernel/skales
(cd skales && git log -1)
export PATH=`pwd`/skales:$PATH

# Create version string
echo "$(date +%Y%m%d)-${BUILD_NUMBER}" > build-version

export LANG=C
export make_bootwrapper=false
export make_install=true
export kernel_flavour=lt-qcom
export kernel_config="defconfig distro.config"
export MAKE_DTBS=true
export ARCH=arm64
export toolchain_url=http://releases.linaro.org/components/toolchain/binaries/6.3-2017.02/aarch64-linux-gnu/gcc-linaro-6.3.1-2017.02-x86_64_aarch64-linux-gnu.tar.xz
export tcbindir="${HOME}/srv/toolchain/$(basename $toolchain_url .tar.xz)/bin"

test -d lci-build-tools || git clone https://git.linaro.org/git/ci/lci-build-tools.git lci-build-tools
bash -x lci-build-tools/jenkins_kernel_build_inst

# record compiler version
$(ls ${tcbindir}/*-gcc) -v

# record kernel version
echo "$(make kernelversion)-${VENDOR}-${kernel_flavour}" > kernel-version

# Create the hardware pack
cat << EOF > ${VENDOR}-lt-qcom.default
format: '3.0'
name: ${VENDOR}-lt-qcom
architectures:
- arm64
origin: Linaro
maintainer: Linaro Platform <linaro-dev@lists.linaro.org>
support: supported
serial_tty: ${SERIAL_CONSOLE}
kernel_addr: '0x80208000'
initrd_addr: '0x83000000'
load_addr: '0x60008000'
dtb_addr: '0x61000000'
partition_layout: bootfs_rootfs
mmc_id: '0:1'
kernel_file: boot/Image-*-qcom
initrd_file: boot/initrd.img-*-qcom
dtb_file: lib/firmware/*-qcom/device-tree/msm8916-mtp.dtb
boot_script: boot.scr
boot_min_size: 64
extra_serial_options:
- console=tty0
- console=${SERIAL_CONSOLE},115200n8
assume_installed:
- adduser
- apt
- apt-utils
- debconf-i18n
- debian-archive-keyring
- gcc-6
- gnupg
- ifupdown
- initramfs-tools
- iproute2
- irqbalance
- isc-dhcp-client
- kmod
- netbase
- udev
- linaro-artwork
- systemd
sources:
  qcom: http://obs.linaro.org/qcom/${OS_FLAVOUR} ./
  repo: http://obs.linaro.org/linaro-overlay-${OS_FLAVOUR}/Debian_9.0 ./
  debian: http://deb.debian.org/debian/ ${OS_FLAVOUR} main contrib non-free
packages:
- linux-image-arm64
- linux-headers-arm64
- firmware-linux
- wcnss-start
EOF

# Build information
cat > out/HEADER.textile << EOF

h4. QCOM Landing Team - $BUILD_DISPLAY_NAME

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* OS flavour: $OS_FLAVOUR
* Kernel tree: "$GIT_URL":$GIT_URL
* Kernel branch: $KERNEL_BRANCH
* Kernel version: $(cat kernel-version)
* Kernel commit: "$GIT_COMMIT":$GIT_URL/commit/?id=$GIT_COMMIT
* Kernel defconfig: $kernel_config
* Kernel toolchain: "$(basename $toolchain_url)":$toolchain_url
EOF

# Download license file and firmware
if [ -n "${QCOM_FIRMWARE}" ]; then
    rm -rf qcom_firmware && mkdir qcom_firmware && cd qcom_firmware
    wget -q ${QCOM_FIRMWARE}
    echo "${QCOM_FIRMWARE_MD5}  $(basename ${QCOM_FIRMWARE})" > MD5
    md5sum -c MD5
    unzip $(basename ${QCOM_FIRMWARE})
    # check LICENSE file (for Linux BSP)
    echo "${QCOM_FIRMWARE_LICENSE_MD5}  LICENSE" > MD5
    md5sum -c MD5
    cd -

    sudo MTOOLS_SKIP_CHECK=1 mcopy -i qcom_firmware/linux-board-support-package-*/bootloaders-linux/NON-HLOS.bin \
         ::image/modem.* ::image/mba.mbn ::image/wcnss.* qcom_firmware/linux-board-support-package-*/proprietary-linux
fi

for rootfs in ${ROOTFS}; do

    rootfs_arch=$(echo $rootfs | cut -f2 -d,)
    rootfs_sz=$(echo $rootfs | cut -f3 -d,)
    rootfs=$(echo $rootfs | cut -f1 -d,)

    cat ${VENDOR}-lt-qcom.default > ${VENDOR}-lt-qcom

    # additional packages in desktop images
    [ "${rootfs}" = "alip" ] && cat << EOF >> ${VENDOR}-lt-qcom
- 96boards-artwork
EOF

    rm -f `ls hwpack_${VENDOR}-lt-qcom_*_${rootfs_arch}_supported.tar.gz`
    VERSION=$(cat build-version)
    linaro-hwpack-create --debug ${VENDOR}-lt-qcom ${VERSION}
    linaro-hwpack-replace -t `ls hwpack_${VENDOR}-lt-qcom_*_${rootfs_arch}_supported.tar.gz` -p `ls linux-image-*-${VENDOR}-lt-qcom_*.deb` -r linux-image -d -i
    linaro-hwpack-replace -t `ls hwpack_${VENDOR}-lt-qcom_*_${rootfs_arch}_supported.tar.gz` -p `ls linux-headers-*-${VENDOR}-lt-qcom_*.deb` -r linux-headers -d -i

    # Get rootfs
    export ROOTFS_BUILD_NUMBER=`wget -q --no-check-certificate -O - https://ci.linaro.org/jenkins/job/${OS_FLAVOUR}-${rootfs_arch}-rootfs/label=docker-jessie-${rootfs_arch},rootfs=${rootfs}/lastSuccessfulBuild/buildNumber`
    export ROOTFS_BUILD_TIMESTAMP=`wget -q --no-check-certificate -O - https://ci.linaro.org/jenkins/job/${OS_FLAVOUR}-${rootfs_arch}-rootfs/label=docker-jessie-${rootfs_arch},rootfs=${rootfs}/lastSuccessfulBuild/buildTimestamp?format=yyyyMMdd`
    export ROOTFS_BUILD_URL="http://snapshots.linaro.org/debian/images/${OS_FLAVOUR}/${rootfs}-${rootfs_arch}/${ROOTFS_BUILD_NUMBER}/linaro-${OS_FLAVOUR}-${rootfs}-${ROOTFS_BUILD_TIMESTAMP}-${ROOTFS_BUILD_NUMBER}.tar.gz"
    wget --progress=dot -e dotbytes=2M ${ROOTFS_BUILD_URL}

    # Create pre-built image(s)
    linaro-media-create --dev fastmodel --output-directory ${WORKSPACE}/out --image-file ${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.sd.img --image-size 3G --binary linaro-${OS_FLAVOUR}-${rootfs}-${ROOTFS_BUILD_TIMESTAMP}-${ROOTFS_BUILD_NUMBER}.tar.gz --hwpack hwpack_${VENDOR}-lt-qcom_*.tar.gz --hwpack-force-yes --bootloader uefi

    # Create eMMC rootfs image(s)
    mkdir -p rootfs rootfs2
    for device in $(sudo kpartx -avs out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.sd.img | cut -d' ' -f3); do
        partition=$(echo ${device} | cut -d'p' -f3)
        [ "${partition}" = "2" ] && sudo mount -o loop /dev/mapper/${device} rootfs
    done

    sudo rm -rf rootfs/dev rootfs/boot rootfs/var/lib/apt/lists
    sudo mkdir rootfs/dev rootfs/boot rootfs/var/lib/apt/lists

    # clean up fstab
    sudo sed -i '/UUID/d' rootfs/etc/fstab

    if [ -n "${QCOM_FIRMWARE}" ]; then
        # add license file in the generated rootfs
        sudo cp -f qcom_firmware/linux-board-support-package-*/LICENSE rootfs/etc/QCOM-LINUX-BOARD-SUPPORT-LICENSE

        # add firmware (adreno, dsp, venus and WCN)
        sudo cp -a qcom_firmware/linux-board-support-package-*/proprietary-linux/* rootfs/lib/firmware
    fi

    if [ "${rootfs}" = "installer" ]; then
        # no need to resize rootfs for SD card boot
        sudo rm -f rootfs/lib/systemd/system/resize-helper.service
        # needed by GUI installer
        cat << EOF | sudo tee -a rootfs/etc/fstab
/dev/mmcblk1p9 /mnt vfat defaults 0 0
EOF
    fi

    # Disable Network Manager MAC randomization during scan
    # https://bugs.96boards.org/show_bug.cgi?id=465
    if [ -f rootfs/etc/NetworkManager/NetworkManager.conf ]; then
        cat << EOF | sudo tee -a rootfs/etc/NetworkManager/NetworkManager.conf

[device]
wifi.scan-rand-mac-address=no
EOF
    fi

    sudo mkfs.ext4 -L rootfs out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.img.raw ${rootfs_sz}
    sudo mount -o loop out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.img.raw rootfs2
    sudo cp -a rootfs/* rootfs2
    rootfs_sz_real=$(sudo du -sh rootfs2 | cut -f1)
    sudo umount rootfs rootfs2
    sudo ext2simg -v out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.img.raw out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.img
    sudo kpartx -dv out/${VENDOR}-${OS_FLAVOUR}-*.sd.img
    sudo rm -f out/${VENDOR}-${OS_FLAVOUR}-*.sd.img out/${VENDOR}-${OS_FLAVOUR}-*.img.raw

    # Compress image(s)
    gzip -9 out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.img

    cat >> out/HEADER.textile << EOF
* Linaro Debian ${rootfs}: "http://snapshots.linaro.org/debian/images/${OS_FLAVOUR}/${rootfs}-${rootfs_arch}/${ROOTFS_BUILD_NUMBER}":http://snapshots.linaro.org/debian/images/${OS_FLAVOUR}/${rootfs}-${rootfs_arch}/${ROOTFS_BUILD_NUMBER} , size: ${rootfs_sz_real}
EOF
done

# Move all relevant DTBs in out/, if DTBS is not specified, use all qcom DTS
DTBS="${DTBS:-arch/arm64/boot/dts/qcom/*.dts}"
for f in ${DTBS} ; do
    # f is a .dtb or .dts file
    [ -e "out/dtbs/$f" ] || f=$(basename ${f} .dts).dtb
    mv out/dtbs/${f} out/
done
rm -rf out/dtbs

# Create device tree table
dtbTool -o out/dt.img -s ${BOOTIMG_PAGESIZE} out/

# Create boot image
mkbootimg \
    --kernel out/Image \
    --ramdisk "out/initrd.img-$(cat kernel-version)" \
    --output out/boot-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${VERSION}.img \
    --dt out/dt.img \
    --pagesize "${BOOTIMG_PAGESIZE}" \
    --base "0x80000000" \
    --cmdline "root=/dev/disk/by-partlabel/${ROOTFS_PARTLABEL} rw rootwait console=tty0 console=${SERIAL_CONSOLE},115200n8"
gzip -9 out/boot-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${VERSION}.img

# Final preparation for publishing
cp -a linux-*.deb out/
