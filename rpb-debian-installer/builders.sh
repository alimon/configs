#!/bin/bash
set -ex

sudo cp local.list /etc/apt/sources.list.d/
cat > linaro.pref <<EOF
Package: *
Pin: release n=stretch-backports
Pin-Priority: 500
EOF
sudo cp linaro.pref /etc/apt/preferences.d/

# d-i build is triggered from rpb-kernel-latest-metapackage job with
# kernel_abi_version given as argument
# we loop waiting for OBS to build package so we can generate d-i with latest
# kernel
# if not done in 2h then let it try to do build or fail

for loop_counter in $(seq 1 12)
do
	sleep 600

	sudo apt-get update -q

	# Find kernel abi
	KERNEL_ABI=`apt-cache show linux-image-reference-arm64 | grep -m 1 Depends | sed -e "s/.*linux-image-//g" -e "s/-arm64.*//g"`


	# if called directly from CI then kernel_abi_version may be unset
	if [ -z $kernel_abi_version ]; then
		kernel_abi_version=$KERNEL_ABI
	fi

	if [ $KERNEL_ABI == $kernel_abi_version ]; then
		break;
	fi
done

# Build the installer
DEB_INSTALLER_VERSION="20170615+deb9u2"
dget https://deb.debian.org/debian/pool/main/d/debian-installer/debian-installer_${DEB_INSTALLER_VERSION}.dsc
cd debian-installer-*
sudo apt-get build-dep -q --no-install-recommends -y .
## https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=810654, so lava can use grub to load grub.cfg from the local disk
sed -i 's/fshelp|//g' build/util/grub-cpmodules

# Config changes
cd build
cp ../../sources.list.udeb .
sed -i "s/LINUX_KERNEL_ABI.*/LINUX_KERNEL_ABI = $KERNEL_ABI/g" config/common
sed -i "s/PRESEED.*/PRESEED = default-preseed/g" config/common
sed -i "s/USE_UDEBS_FROM.*/USE_UDEBS_FROM = stretch/g" config/common

# Local pkg-list (to include all udebs)
cat <<EOF > pkg-lists/local
ext4-modules-\${kernel:Version}
fat-modules-\${kernel:Version}
btrfs-modules-\${kernel:Version}
md-modules-\${kernel:Version}
efi-modules-\${kernel:Version}
scsi-modules-\${kernel:Version}
jfs-modules-\${kernel:Version}
xfs-modules-\${kernel:Version}
ata-modules-\${kernel:Version}
sata-modules-\${kernel:Version}
usb-storage-modules-\${kernel:Version}
EOF
cat ../../localudebs >> pkg-lists/local
cp ../../default-preseed .

sed -i -e 's/virtio-modules.*//g' pkg-lists/netboot/arm64.cfg
echo "firmware-qlogic" >> pkg-lists/netboot/arm64.cfg
echo "firmware-bnx2x" >> pkg-lists/netboot/arm64.cfg

fakeroot make build_netboot
cd ../..

cp debian-installer-*/build/dest/netboot/mini.iso .
cp debian-installer-*/build/dest/netboot/netboot.tar.gz .

# Final preparation for publishing
mkdir out
cp -a debian-installer-*/build/default-preseed out/default-preseed.cfg
cp -a mini.iso netboot.tar.gz out/
cd out; tar xaf netboot.tar.gz ./debian-installer/arm64/{linux,initrd.gz}; cd ..

# Create MD5SUMS file
(cd out && find -type f -exec md5sum {} \; | sed "s/  \.\//  /g" > MD5SUMS.txt)

