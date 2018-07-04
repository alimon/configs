#!/bin/bash

set -x

wget_error() {
	wget -c $1 -P out/
	retcode=$?
	if [ $retcode -ne 0 ]; then
		exit $retcode
	fi
}

# Set default tools to use
if [ -z "${GZ}" ]; then
	export GZ=gzip
fi

# Set per MACHINE configuration
case "${MACHINE}" in
	dragonboard410c)
		KERNEL_DT_URL=${KERNEL_DT_URL_dragonboard410c}
		ROOTFS_URL=${ROOTFS_URL_dragonboard410c}
		BOOTIMG_PAGESIZE=2048
		BOOTIMG_BASE=0x80000000
		RAMDISK_BASE=0x84000000
		ROOTFS_PARTITION=/dev/mmcblk0p10
		SERIAL_CONSOLE=ttyMSM0
		;;
	dragonboard820c)
		KERNEL_DT_URL=${KERNEL_DT_URL_dragonboard820c}
		ROOTFS_URL=${ROOTFS_URL_dragonboard820c}
		BOOTIMG_PAGESIZE=4096
		BOOTIMG_BASE=0x80000000
		RAMDISK_BASE=0x84000000
		ROOTFS_PARTITION=/dev/sda7
		SERIAL_CONSOLE=ttyMSM0
		;;
	sdm845_mtp)
		KERNEL_DT_URL=${KERNEL_DT_URL_sdm845_mtp}
		ROOTFS_URL=${ROOTFS_URL_sdm845_mtp}
		BOOTIMG_PAGESIZE=2048
		BOOTIMG_BASE=0x80000000
		RAMDISK_BASE=0x84000000
		SERIAL_CONSOLE=ttyMSM0
		;;
	*)
		echo "Currently MACHINE: ${MACHINE} isn't supported"
		exit 1
		;;
esac

# Validate required parameters
if [ -z "${KERNEL_IMAGE_URL}" ]; then
	echo "ERROR: KERNEL_IMAGE_URL is empty"
	exit 1
fi
if [ -z "${ROOTFS_URL}" ]; then
	echo "ERROR: ROOTFS_URL is empty"
	exit 1
fi

# Build information
mkdir -p out
cat > out/HEADER.textile << EOF

h4. QCOM Landing Team - $BUILD_DISPLAY_NAME

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Kernel image URL: $KERNEL_IMAGE_URL
* Kernel dt URL: $KERNEL_DT_URL
* kernel modules URL: $KERNEL_MODULES_URL
* Rootfs URL: $ROOTFS_URL
EOF

# Rootfs image, modules populate
wget_error ${ROOTFS_URL}
if [[ ! -z "${KERNEL_MODULES_URL}" ]]; then
	wget_error ${KERNEL_MODULES_URL}
fi
rootfs_file=out/$(basename ${ROOTFS_URL})
rootfs_file_type=$(file $rootfs_file)

rootfs_comp=''
if [[ $rootfs_file_type = *"gzip compressed data"* ]]; then
	${GZ} -d $rootfs_file
	rootfs_file=out/$(basename ${ROOTFS_URL} .gz)
	rootfs_file_type=$(file $rootfs_file)
	rootfs_comp='gz'
fi

if [[ $rootfs_file_type = *"Android sparse image"* ]]; then
	rootfs_file_ext4=out/$(basename ${rootfs_file} .img).ext4
	simg2img $rootfs_file $rootfs_file_ext4
	rootfs_file=$rootfs_file_ext4
elif [[ $rootfs_file_type = *"ext4 filesystem data"* ]]; then
	rootfs_file=$rootfs_file
elif [[ $rootfs_file_type = *"cpio archive"* ]]; then
	rootfs_file=$rootfs_file
else
	echo "ERROR: ROOTFS_IMAGE type isn't supported: $rootfs_file_type"
	exit 1
fi

if [[ ! -z "${KERNEL_MODULES_URL}" ]]; then
	if [[ $rootfs_file_type = *"cpio archive"* ]]; then
		modules_file=out/$(basename ${KERNEL_MODULES_URL})

		mkdir -p out/modules
		tar -xvf out/$(basename ${KERNEL_MODULES_URL}) -C out/modules
		cd out/modules
		find . | cpio -oA -H newc -F ../../$rootfs_file
		cd ../../
		rm -r out/modules
	else
		modules_file=out/$(basename ${KERNEL_MODULES_URL})
		required_size=$(${GZ} -l $modules_file | tail -1 | awk '{print $2}')
		required_size=$(( $required_size / 1024 ))

		sudo e2fsck -y $rootfs_file
		block_count=$(sudo dumpe2fs -h $rootfs_file | grep "Block count" | awk '{print $3}')
		block_size=$(sudo dumpe2fs -h $rootfs_file | grep "Block size" | awk '{print $3}')
		current_size=$(( $block_size * $block_count / 1024 ))

		final_size=$(( $current_size + $required_size + 32768 ))
		sudo resize2fs -p $rootfs_file "$final_size"K

		mkdir -p out/rootfs_mount
		sudo mount -o loop $rootfs_file out/rootfs_mount
		sudo tar -xvf out/$(basename ${KERNEL_MODULES_URL}) -C out/rootfs_mount
		sudo umount out/rootfs_mount
	fi
fi

if [[ $rootfs_file_type = *"Android sparse image"* ]]; then
	rootfs_file_img=out/$(basename $rootfs_file .ext4).img
	img2simg $rootfs_file $rootfs_file_img
	rm $rootfs_file
	rootfs_file=$rootfs_file_img
fi
if [[ $rootfs_comp = "gz" ]]; then
	${GZ} $rootfs_file
	rootfs_file="$rootfs_file".gz
fi

# Compress kernel image if isn't
wget_error ${KERNEL_IMAGE_URL}
kernel_file=out/$(basename ${KERNEL_IMAGE_URL})
kernel_file_type=$(file $kernel_file)
if [[ ! $kernel_file_type = *"gzip compressed data"* ]]; then
	${GZ} -kf $kernel_file
	kernel_file=$kernel_file.gz
fi

# Making android boot img
dt_mkbootimg_arg=""
if [[ ! -z "${KERNEL_DT_URL}" ]]; then
	wget_error ${KERNEL_DT_URL}
	dt_mkbootimg_arg="--dt out/$(basename ${KERNEL_DT_URL})"
fi

# Create boot image
boot_file=boot-${KERNEL_FLAVOR}-${KERNEL_VERSION}-${BUILD_NUMBER}-${MACHINE}.img
if [[ $rootfs_file_type = *"cpio archive"* ]]; then
	ramdisk_file=$rootfs_file
	skales-mkbootimg \
		--kernel $kernel_file \
		--ramdisk $ramdisk_file \
		--output out/$boot_file \
		$dt_mkbootimg_arg \
		--pagesize "${BOOTIMG_PAGESIZE}" \
		--base "${BOOTIMG_BASE}" \
		--ramdisk_base "${RAMDISK_BASE}" \
		--cmdline "root=/dev/ram0 init=/init rw console=tty0 console=${SERIAL_CONSOLE},115200n8"
else
	ramdisk_file=out/initrd.img
	echo "This is not an initrd" > $ramdisk_file
	skales-mkbootimg \
		--kernel $kernel_file \
		--ramdisk $ramdisk_file \
		--output out/$boot_file \
		$dt_mkbootimg_arg \
		--pagesize "${BOOTIMG_PAGESIZE}" \
		--base "${BOOTIMG_BASE}" \
		--ramdisk_base "${RAMDISK_BASE}" \
		--cmdline "root=${ROOTFS_PARTITION} rw rootwait console=tty0 console=${SERIAL_CONSOLE},115200n8"
fi

echo BOOT_FILE=$boot_file >> builders_out_parameters

ls -l out/
