#!/bin/bash

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
  sudo umount bootfs || true
  sudo umount rootfs || true
  sudo kpartx -dv hikey-sd-install.img || true
  rm -rf hikey-sd-install.img out
}

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -q=2
sudo apt-get install -q=2 -y --no-install-recommends pigz

# Get installer rootfs
export ROOTFS_BUILD_TIMESTAMP=$(wget -q  -O - https://ci.linaro.org/job/debian-arm64-rootfs/label=docker-jessie-arm64,rootfs=installer/lastSuccessfulBuild/buildTimestamp?format=yyyyMMdd)
export ROOTFS_BUILD_NUMBER=$(wget -q  -O - https://ci.linaro.org/job/debian-arm64-rootfs/label=docker-jessie-arm64,rootfs=installer/lastSuccessfulBuild/buildNumber)
export ROOTFS_BUILD_URL="http://snapshots.linaro.org/debian/images/installer-arm64/${ROOTFS_BUILD_NUMBER}/linaro-jessie-installer-${ROOTFS_BUILD_TIMESTAMP}-${ROOTFS_BUILD_NUMBER}.tar.gz"
wget -nc --progress=dot -e dotbytes=2M ${ROOTFS_BUILD_URL}

mkdir -p out bootfs rootfs

# Build information
cat > out/HEADER.textile << EOF

h4. Reference Platform Build - Installer for HiKey

Build description:
* Build URL: "${BUILD_URL}":${BUILD_URL}
* Installer Rootfs: "${ROOTFS_BUILD_URL}":${ROOTFS_BUILD_URL}
EOF

# set up partitions
dd if=/dev/zero of=hikey-sd-install.img bs=2096 seek=1M count=0
/sbin/parted --script hikey-sd-install.img mklabel msdos
/sbin/parted --script hikey-sd-install.img mkpart p fat16 0 50
/sbin/parted --script hikey-sd-install.img set 1 boot
/sbin/parted --script -- hikey-sd-install.img mkpart p ext4 50 -0

for device in $(sudo kpartx -avs hikey-sd-install.img | cut -d' ' -f3); do
  partition=$(echo ${device} | cut -d'p' -f3)
  case "${partition}" in
    1)
      sudo mkfs.fat -F16 /dev/mapper/${device}
      sudo mount /dev/mapper/${device} bootfs
      ;;
    2)
      sudo mkfs.ext4 /dev/mapper/${device}
      sudo mount /dev/mapper/${device} rootfs
      sudo tar xf linaro-jessie-installer-${ROOTFS_BUILD_TIMESTAMP}-${ROOTFS_BUILD_NUMBER}.tar.gz -C rootfs --strip-components=1
      ;;
  esac
done

sudo mkdir -p rootfs/mnt/debian rootfs/boot/efi/EFI/BOOT
sudo chroot rootfs apt-get update -q=2
sudo chroot rootfs apt-get install -q=2 -y linux-image-reference-arm64
sudo rm rootfs/var/cache/apt/archives/*deb rootfs/var/lib/apt/lists/*||true
sudo chroot rootfs /usr/sbin/grub-install-hikey -s
sudo cp -a rootfs/boot/efi/* bootfs/
sudo chown ${USER}:${USER} rootfs/mnt/debian

# download alip image for flash
export ROOTFS_BUILD_TIMESTAMP=$(wget -q  -O - https://ci.linaro.org/job/96boards-reference-platform-debian/BOARD=hikey,label=docker-jessie-amd64/lastSuccessfulBuild/buildTimestamp?format=yyyyMMdd)
export ROOTFS_BUILD_NUMBER=$(wget -q  -O - https://ci.linaro.org/job/96boards-reference-platform-debian/BOARD=hikey,label=docker-jessie-amd64/lastSuccessfulBuild/buildNumber)
export TARGET_ROOT_URL="https://snapshots.linaro.org/96boards/reference-platform/debian/${ROOTFS_BUILD_NUMBER}/hikey/hikey-rootfs-debian-jessie-alip-${ROOTFS_BUILD_TIMESTAMP}-${ROOTFS_BUILD_NUMBER}.emmc.img.gz"
export TARGET_BOOT_URL="https://snapshots.linaro.org/96boards/reference-platform/debian/${ROOTFS_BUILD_NUMBER}/hikey/hikey-boot-linux-${ROOTFS_BUILD_TIMESTAMP}-${ROOTFS_BUILD_NUMBER}.uefi.img.gz"
wget -nc --progress=dot -e dotbytes=2M -O rootfs/mnt/debian/rootfs.img.gz ${TARGET_ROOT_URL}
wget -nc --progress=dot -e dotbytes=2M -O rootfs/mnt/debian/boot.img.gz ${TARGET_BOOT_URL}

sudo cp -a rootfs/usr/share/96boards-tools/flash-hikey rootfs/mnt/flash

cat << EOF > rootfs/mnt/debian/os.json
{
    "name": "Reference platform Debian Desktop for hikey - Build ${BUILD_NUMBER}",
    "url": "http://releases.linaro.org/96boards/installer/hikey",
    "version": "${ROOTFS_BUILD_NUMBER}",
    "release_date": "$(date +%Y-%m-%d)",
    "description": "Reference platform Debian LXDE desktop for hikey"
}
EOF

sudo umount bootfs rootfs
sudo kpartx -dv hikey-sd-install.img
time pigz -9 hikey-sd-install.img
mv hikey-sd-install.img.gz out/hikey-sd-installer-${BUILD_NUMBER}.img.gz

# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python ${HOME}/bin/linaro-cp.py \
  --server ${PUBLISH_SERVER} \
  --link-latest \
  out/ 96boards/reference-platform/installer/hikey/${BUILD_NUMBER}/
