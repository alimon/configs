#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    cd ${WORKSPACE}
    sudo kpartx -dv out/${VENDOR}-${OS_FLAVOUR}-*.sd.img || true
    sudo git clean -fdxq
}

sudo apt-get update
sudo apt-get install -y kpartx python-requests device-tree-compiler zip android-tools-fsutils
wget -q \
     http://repo.linaro.org/ubuntu/linaro-tools/pool/main/l/linaro-image-tools/linaro-image-tools_2016.05-1linarojessie1_amd64.deb \
     http://repo.linaro.org/ubuntu/linaro-tools/pool/main/l/linaro-image-tools/python-linaro-image-tools_2016.05-1linarojessie1_all.deb
sudo dpkg -i --force-all *.deb
rm -f *.deb

export LANG=C
export make_bootwrapper=false
export make_install=true
export kernel_flavour=lt-qcom
export kernel_config="qcom_defconfig distro.config"
export MAKE_DTBS=true
export toolchain_url=http://releases.linaro.org/components/toolchain/binaries/6.3-2017.02/arm-linux-gnueabihf/gcc-linaro-6.3.1-2017.02-x86_64_arm-linux-gnueabihf.tar.xz
export tcbindir="${HOME}/srv/toolchain/$(basename $toolchain_url .tar.xz)/bin"

test -d lci-build-tools || git clone https://git.linaro.org/git/ci/lci-build-tools.git lci-build-tools
bash -x lci-build-tools/jenkins_kernel_build_inst

# record compiler version
$(ls ${tcbindir}/*-gcc) -v

# Create the hardware pack
cat << EOF > ${VENDOR}-lt-qcom.default
format: '3.0'
name: ${VENDOR}-lt-qcom
architectures:
- armhf
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
kernel_file: boot/vmlinuz-*-qcom
initrd_file: boot/initrd.img-*-qcom
dtb_file: lib/firmware/*-qcom/device-tree/qcom-apq8064-ifc6410.dtb
dtb_files:
- qcom-apq8064-ifc6410.dtb: lib/firmware/*-qcom/device-tree/qcom-apq8064-ifc6410.dtb
- qcom-apq8064-cm-qs600.dtb: lib/firmware/*-qcom/device-tree/qcom-apq8064-cm-qs600.dtb
- qcom-apq8064-eI_ERAGON600.dtb: lib/firmware/*-qcom/device-tree/qcom-apq8064-eI_ERAGON600.dtb
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
- gcc-4.9
- gnupg
- ifupdown
- initramfs-tools
- iproute2
- irqbalance
- isc-dhcp-client
- kmod
- netbase
- udev
sources:
  qcom: http://repo.linaro.org/ubuntu/qcom-overlay ${OS_FLAVOUR} main
  repo: http://repo.linaro.org/ubuntu/linaro-overlay ${OS_FLAVOUR} main
  debian: http://ftp.debian.org/debian/ ${OS_FLAVOUR} main contrib non-free
  backports: http://ftp.debian.org/debian/ ${OS_FLAVOUR}-backports main
packages:
- linux-image-armmp
- linux-headers-armmp
EOF

# Build information
cat > out/HEADER.textile << EOF

h4. QCOM Landing Team - Snapdragon 600 - Debian

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* OS flavour: $OS_FLAVOUR
* Kernel tree: "$GIT_URL":$GIT_URL
* Kernel branch: $KERNEL_BRANCH
* Kernel version: "$GIT_COMMIT":$GIT_URL/commit/?id=$GIT_COMMIT
* Kernel defconfig: $kernel_config
* Kernel toolchain: "$(basename $toolchain_url)":$toolchain_url
EOF

for rootfs in ${ROOTFS}; do

    rootfs_arch=$(echo $rootfs | cut -f2 -d,)
    rootfs_sz=$(echo $rootfs | cut -f3 -d,)
    rootfs=$(echo $rootfs | cut -f1 -d,)

    cat ${VENDOR}-lt-qcom.default > ${VENDOR}-lt-qcom

    # additional packages in desktop images
    [ "${rootfs}" != "developer" ] && cat << EOF >> ${VENDOR}-lt-qcom
- xserver-xorg-video-freedreno
EOF

    rm -f `ls hwpack_${VENDOR}-lt-qcom_*_${rootfs_arch}_supported.tar.gz`
    VERSION=`date +%Y%m%d`-${BUILD_NUMBER}
    linaro-hwpack-create --debug --backports ${VENDOR}-lt-qcom ${VERSION}
    linaro-hwpack-replace -t `ls hwpack_${VENDOR}-lt-qcom_*_${rootfs_arch}_supported.tar.gz` -p `ls linux-image-*-${VENDOR}-lt-qcom_*.deb` -r linux-image -d -i
    linaro-hwpack-replace -t `ls hwpack_${VENDOR}-lt-qcom_*_${rootfs_arch}_supported.tar.gz` -p `ls linux-headers-*-${VENDOR}-lt-qcom_*.deb` -r linux-headers -d -i

    # Get rootfs
    export ROOTFS_BUILD_NUMBER=`wget -q --no-check-certificate -O - https://ci.linaro.org/jenkins/job/debian-${rootfs_arch}-rootfs/label=docker-jessie-${rootfs_arch},rootfs=${rootfs}/lastSuccessfulBuild/buildNumber`
    export ROOTFS_BUILD_TIMESTAMP=`wget -q --no-check-certificate -O - https://ci.linaro.org/jenkins/job/debian-${rootfs_arch}-rootfs/label=docker-jessie-${rootfs_arch},rootfs=${rootfs}/lastSuccessfulBuild/buildTimestamp?format=yyyyMMdd`
    export ROOTFS_BUILD_URL="http://snapshots.linaro.org/debian/images/${rootfs}-${rootfs_arch}/${ROOTFS_BUILD_NUMBER}/linaro-${OS_FLAVOUR}-${rootfs}-${ROOTFS_BUILD_TIMESTAMP}-${ROOTFS_BUILD_NUMBER}.tar.gz"
    wget --progress=dot -e dotbytes=2M ${ROOTFS_BUILD_URL}

    # Create pre-built image(s)
    linaro-media-create --dev fastmodel --output-directory ${WORKSPACE}/out --image-file ${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.sd.img --image-size 2G --binary linaro-${OS_FLAVOUR}-${rootfs}-${ROOTFS_BUILD_TIMESTAMP}-${ROOTFS_BUILD_NUMBER}.tar.gz --hwpack hwpack_${VENDOR}-lt-qcom_*.tar.gz --hwpack-force-yes --bootloader uefi

    # Create eMMC rootfs image(s)
    mkdir rootfs
    for device in $(sudo kpartx -avs out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.sd.img | cut -d' ' -f3); do
        partition=$(echo ${device} | cut -d'p' -f3)
        [ "${partition}" = "2" ] && sudo mount -o loop /dev/mapper/${device} rootfs
    done

    sudo rm -rf rootfs/dev rootfs/boot rootfs/var/lib/apt/lists
    sudo mkdir rootfs/dev rootfs/boot rootfs/var/lib/apt/lists

    # clean up fstab
    sudo sed -i '/UUID/d' rootfs/etc/fstab

    cat << EOF | sudo tee -a rootfs/etc/fstab
LABEL=qcom-firmware /lib/firmware ext4 defaults 0 0
EOF

    sudo mkfs.ext4 -L rootfs out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.img.raw ${rootfs_sz}
    mkdir rootfs2
    sudo mount -o loop out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.img.raw rootfs2
    sudo cp -a rootfs/* rootfs2
    rootfs_sz_real=$(sudo du -sh rootfs2 | cut -f1)
    sudo umount rootfs2 rootfs
    sudo ext2simg -v out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.img.raw out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.img
    sudo kpartx -dv out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.sd.img
    sudo rm -rf rootfs out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.sd.img rootfs2 out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.img.raw

    # Compress image(s)
    gzip -9 out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${VERSION}.img

    cat >> out/HEADER.textile << EOF
* Linaro Debian ${rootfs}: "http://snapshots.linaro.org/debian/images/${rootfs}-${rootfs_arch}/${ROOTFS_BUILD_NUMBER}":http://snapshots.linaro.org/debian/images/${rootfs}-${rootfs_arch}/${ROOTFS_BUILD_NUMBER} , size: ${rootfs_sz_real}
EOF
done

# Create boot image(s)
cat > out/bootimg.cfg << EOF
bootsize = 0xA00000
pagesize = 0x800
kerneladdr = 0x80208000
ramdiskaddr = 0x83000000
secondaddr = 0x81100000
tagsaddr = 0x80200100
name = ${VENDOR}-${PLATFORM_NAME}
cmdline = console=tty0 console=${SERIAL_CONSOLE},115200n8 root=/dev/disk/by-partlabel/userdata rootwait rw systemd.unit=multi-user.target
EOF

# Create one boot image for each platform supported, since we need to append DTB to zImage
for f in ${DTBS} ; do
    mv out/dtbs/${f} out/
    target=`basename ${f} .dtb`
    cat out/zImage out/${f} > zImage-dtb
    abootimg --create out/boot-${target}-${PLATFORM_NAME}-${VERSION}.img -f out/bootimg.cfg -k zImage-dtb -r out/initrd.img-*
    gzip -9 out/boot-${target}-${PLATFORM_NAME}-${VERSION}.img
done
rm -rf out/dtbs

# Create an empty partition, placeholder for proprietary firmware
# do no create sparse file, so that the file can be easily loop mounted
mkdir qcom-firmware
sudo make_ext4fs -L qcom-firmware -l 64M out/firmware-${PLATFORM_NAME}-${VERSION}.img qcom-firmware/
rm -rf qcom-firmware
gzip -9 out/firmware-${PLATFORM_NAME}-${VERSION}.img

# Final preparation for publishing
cp -a linux-*.deb out/
rm -f out/vmlinuz

# Create MD5SUMS file
(cd out && md5sum * > MD5SUMS.txt)

# Publish to snapshots
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
     --api_version 3 \
     --link-latest \
     out debian/pre-built/snapdragon/${BUILD_NUMBER}
