#!/bin/bash

set -x

wget_error() {
	wget -c $1 -P out/
	retcode=$?
	if [ $retcode -ne 0 ]; then
		exit $retcode
	fi
}

function copy_archive_to_rootfs() {
	archive_file=$1
	archive_file_type=$2
	target_file=$3
	target_file_type=$4

	if [[ $target_file_type = *"cpio archive"* ]]; then
		mkdir -p out/archive
		if [[ $archive_file_type = *"Debian binary package"* ]]; then
			dpkg-deb -x $archive_file out/archive
		else
			tar -xvf $archive_file -C out/archive
		fi
		cd out/archive
		find . | cpio -R 0:0 -oA -H newc -F ../../$target_file
		cd ../../
		rm -rf out/archive
	else
		set -e
		archive_tmpd="out/archive"

		if [[ $archive_file_type = *"Debian binary package"* ]]; then
			required_size=$(dpkg -f $archive_file Installed-Size)
		else
			required_size=$(${GZ} -l $archive_file | tail -1 | awk '{print $2}')
		fi
		required_size=$(( $required_size / 1024 ))

		sudo e2fsck -y -f $target_file
		block_count=$(sudo dumpe2fs -h $target_file | grep "Block count" | awk '{print $3}')
		block_size=$(sudo dumpe2fs -h $target_file | grep "Block size" | awk '{print $3}')
		current_size=$(( $block_size * $block_count / 1024 ))

		final_size=$(( $current_size + $required_size + 32768 ))
		sudo resize2fs -p $target_file "$final_size"K

		sudo mkdir -p $archive_tmpd
		if [[ $archive_file_type = *"Debian binary package"* ]]; then
			sudo dpkg-deb -x $archive_file $archive_tmpd
		else
			sudo tar -xvf $archive_file -C $archive_tmpd
		fi

		cdir=$(pwd)
		pushd $cdir
		cd $archive_tmpd
		for f in $(find . -type f)
		do
			e2cp -a -p -G 0 -O 0 -v $f $cdir/$target_file:/
		done
		for l in $(find . -type l)
		do
			f=$(readlink -f $l) || continue
			if [ -f "$f" ]; then
				e2cp -p -G 0 -O 0 -v $f $cdir/$target_file:/$l
			fi
		done
		popd
		sudo rm -rf $archive_tmpd

		set +e
	fi
}

function remove_unused_firmware() {
	target_file=$1
	target_file_type=$2

	# Remove all not needed firmware by platform, In db845c it ran out of space causing
	# boot failure.
	case "${MACHINE}" in
		apq8016-sbc|apq8096-db820c|sdm845-db845c)
			mkdir -p out/archive
			cd out/archive
			cpio -idv -H newc < ../../$target_file

			if [ "${MACHINE}" = "apq8016-sbc" ]; then
				rm -rf lib/firmware/ar* lib/firmware/htc* lib/firmware/wil* lib/firmware/qca*
				rm -rf lib/firmware/ath* lib/firmware/LICENSE.QualcommAtheros_ath10k
				rm -rf lib/firmware/qcom/a530* lib/firmware/qcom/a630*
				rm -rf lib/firmware/qcom/msm8996 lib/firmware/qcom/sdm845 lib/firmware/K2026090.mem
				rm -rf lib/firmware/qcom/venus-4.2 lib/firmware/qcom/venus-5.2 lib/firmware/qcom/venus-5.4
			elif [ "${MACHINE}" = "apq8096-db820c" ]; then
				rm -rf lib/firmware/ar* lib/firmware/htc* lib/firmware/wil* lib/firmware/qca*
				rm -rf lib/firmware/ath3* lib/firmware/ath6* lib/firmware/ath9* 
				rm -rf lib/firmware/ath10k/QCA4* lib/firmware/ath10k/QCA9* lib/firmware/ath10k/WCN*
				rm -rf lib/firmware/a300* lib/firmware/qcom/a300* lib/firmware/qcom/a630*
				rm -rf lib/firmware/qcom/msm8916 lib/firmware/wlan lib/firmware/qcom/sdm845 lib/firmware/K2026090.mem
				rm -rf lib/firmware/qcom/venus-1.8 lib/firmware/qcom/venus-5.2 lib/firmware/qcom/venus-5.4
			elif [ "${MACHINE}" = "sdm845-db845c" ]; then
				rm -rf lib/firmware/ar* lib/firmware/htc* lib/firmware/wil*
				rm -rf lib/firmware/ath3* lib/firmware/ath6* lib/firmware/ath9* lib/firmware/ath10k/QCA*
				rm -rf lib/firmware/a300* lib/firmware/qcom/a300* lib/firmware/qcom/a530*
				rm -rf lib/firmware/qcom/msm8916 lib/firmware/wlan lib/firmware/qcom/msm8996
				rm -rf lib/firmware/qcom/venus-1.8 lib/firmware/qcom/venus-4.2 lib/firmware/qcom/venus-5.4
			fi

			find . | cpio -R 0:0 -ov -H newc > ../../$target_file
			cd ../../
			rm -rf out/archive
		;;
	esac
}

function create_ramdisk_from_folder() {
	ramdisk_name=$1
	ramdisk_folder=$2
	ramdisk="$ramdisk_name.cpio"

	cd $ramdisk_folder
	find . | cpio -R 0:0 -ov -H newc > "../../out/$ramdisk"
	${GZ} "../../out/$ramdisk"
	ramdisk=$ramdisk.gz
	echo "$ramdisk"
	cd ../
}

function overlay_ramdisk_from_git() {
	git_repo=$1
	git_branch=$2

	# clone git repo and get revision details
	project_name="$(basename "$git_repo" .git)"
	project_folder="$project_name"
	project_ramdisk_folder="$(realpath $project_folder)/rootfs"
	git clone -b "$git_branch" --depth 1 "$git_repo" "$project_folder"
	cd "$project_folder"
	DESTDIR="$project_ramdisk_folder" prefix="/usr" make install 2>&1 > /dev/null
	project_name="$project_name-$(git rev-parse --short HEAD)"

	# created the overlayed ramdisk involves the creation of new ramdisk from folder and
	# concat both into a single file
	project_ramdisk_overlay=$(create_ramdisk_from_folder $project_name $project_ramdisk_folder)
	cd ../

	overlayed_ramdisk_file="$(basename $ramdisk_file)+$(basename $project_ramdisk_overlay)"
	cat "$ramdisk_file" "out/$project_ramdisk_overlay" > "out/$overlayed_ramdisk_file"
	echo "$overlayed_ramdisk_file"
	rm -rf "$project_folder"
}

function overlay_ramdisk_from_file() {
	file_name=$1
	file_cpio="out/$2.cpio"

	echo $file_name | cpio -R 0:0 -ov -H newc > $file_cpio
	${GZ} $file_cpio
	file_cpio=$file_cpio.gz

	overlayed_ramdisk_file="$(basename $ramdisk_file)+$(basename $file_cpio)"
	cat "$ramdisk_file" "$file_cpio" > "out/$overlayed_ramdisk_file"
	echo "$overlayed_ramdisk_file"
}

# Set default tools to use
if [ -z "${GZ}" ]; then
	export GZ=gzip
fi

# Generic/default variables
KERNEL_CI_PLATFORM=${MACHINE}
BOOTIMG_PAGESIZE=2048
BOOTIMG_BASE=0x80000000
RAMDISK_BASE=0x84000000
SERIAL_CONSOLE=ttyMSM0
KERNEL_CI_MACH=qcom
KERNEL_DT_URL="${KERNEL_DT_URL}/qcom/${MACHINE}.dtb"
KERNEL_CMDLINE_APPEND=

# Set per MACHINE configuration
case "${MACHINE}" in
	apq8016-sbc)
		FIRMWARE_URL="${FIRMWARE_URL_apq8016_sbc}"
		ROOTFS_PARTITION=/dev/mmcblk0p14
		;;
	apq8096-db820c)
		FIRMWARE_URL="${FIRMWARE_URL_apq8096_db820c}"
		BOOTIMG_PAGESIZE=4096
		ROOTFS_PARTITION=/dev/sda1
		;;
	sdm845-mtp)
		FIRMWARE_URL="${FIRMWARE_URL_sdm845_mtp}"

		# XXX: using Android userdata since we don't have Linux parttable
		ROOTFS_PARTITION=/dev/disk/by-partlabel/userdata
		;;
	sdm845-db845c)
		BOOTIMG_PAGESIZE=4096
		FIRMWARE_URL="${FIRMWARE_URL_sdm845_db845c}"

		ROOTFS_PARTITION=/dev/sda1
		KERNEL_CMDLINE_APPEND="clk_ignore_unused pd_ignore_unused"
		;;
	qcs404-evb-1000)
		FIRMWARE_URL="${FIRMWARE_URL_qcs404_evb_1000}"

		# Use userdata for now.
		ROOTFS_PARTITION=/dev/disk/by-partlabel/userdata
		;;
	qcs404-evb-4000)
		FIRMWARE_URL="${FIRMWARE_URL_qcs404_evb_4000}"

		# Use userdata for now.
		ROOTFS_PARTITION=/dev/disk/by-partlabel/userdata
		;;
	qrb5165-rb5)
		# Use userdata for now.
		ROOTFS_PARTITION=/dev/disk/by-partlabel/userdata
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

# find rootfs and ramdisk to use
python configs/lt-qcom-linux-test/get_latest_testimage.py
RAMDISK_URL=$(cat output.log  | grep RAMDISK_URL | cut -d= -f2)
ROOTFS_URL=$(cat output.log  | grep ROOTFS_URL | cut -d= -f2)
ROOTFS_DESKTOP_URL=$(cat output.log  | grep ROOTFS_DESKTOP_URL | cut -d= -f2)

# Build information
mkdir -p out
cat > out/HEADER.textile << EOF

h4. QCOM Landing Team - $BUILD_DISPLAY_NAME

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Kernel image URL: $KERNEL_IMAGE_URL
* Kernel dt URL: $KERNEL_DT_URL
* kernel modules URL: $KERNEL_MODULES_URL
* Ramdisk URL: $RAMDISK_URL
* RootFS URL: $ROOTFS_URL
* Firmware URL: $FIRMWARE_URL
EOF

# Ramdisk/RootFS image, firmware and modules populate, download step
wget_error ${RAMDISK_URL}
ramdisk_file=out/$(basename ${RAMDISK_URL})
ramdisk_file_type=$(file $ramdisk_file)

wget_error ${ROOTFS_URL}
rootfs_file=out/$(basename ${ROOTFS_URL})
rootfs_file_type=$(file $rootfs_file)
wget_error ${ROOTFS_DESKTOP_URL}
rootfs_desktop_file=out/$(basename ${ROOTFS_DESKTOP_URL})
rootfs_desktop_file_type=$(file $rootfs_desktop_file)

if [[ ! -z "${KERNEL_MODULES_URL}" ]]; then
	wget_error ${KERNEL_MODULES_URL}
	modules_file="out/$(basename ${KERNEL_MODULES_URL})"

	# XXX: Compress modules to gzip for use copy_archive_to_rootfs
	# generic code to calculate size in ext4 filesystem
	modules_file_type=$(file $modules_file)
	if [[ $modules_file_type = *"XZ compressed data"* ]]; then
		xz -d $modules_file
		modules_file="out/$(basename ${KERNEL_MODULES_URL} .xz)"
		${GZ} $modules_file
		modules_file=$modules_file.gz
	elif [[ $modules_file_type = *"bzip2 compressed data"* ]]; then
		bzip2 -d $modules_file
		modules_file="out/$(basename ${KERNEL_MODULES_URL} .bz2)"
		${GZ} $modules_file
		modules_file=$modules_file.gz
	fi
fi
if [[ ! -z "${FIRMWARE_URL}" ]]; then
	firmware_file=""
	for f in ${FIRMWARE_URL}; do
		wget_error $f
	        firmware_file="$firmware_file out/$(basename $f)"
	done
fi

# Uncompress images to be able populate with firmware and modules
rootfs_desktop_comp=''
if [[ $rootfs_desktop_file_type = *"gzip compressed data"* ]]; then
	${GZ} -d $rootfs_desktop_file
	rootfs_desktop_file=out/$(basename ${ROOTFS_DESKTOP_URL} .gz)
	rootfs_desktop_file_type=$(file $rootfs_desktop_file)
	rootfs_desktop_comp='gz'
fi
rootfs_comp=''
if [[ $rootfs_file_type = *"gzip compressed data"* ]]; then
	${GZ} -d $rootfs_file
	rootfs_file=out/$(basename ${ROOTFS_URL} .gz)
	rootfs_file_type=$(file $rootfs_file)
	rootfs_comp='gz'
fi
if [[ $ramdisk_file_type = *"gzip compressed data"* ]]; then
	${GZ} -d $ramdisk_file
	ramdisk_file=out/$(basename ${RAMDISK_URL} .gz)
	ramdisk_file_type=$(file $ramdisk_file)
	ramdisk_comp='gz'
fi


# If rootfs is Android sparse image convert to ext4 to populate with firmware and modules
if [[ $rootfs_desktop_file_type = *"Android sparse image"* ]]; then
	rootfs_desktop_file_ext4=out/$(basename ${rootfs_desktop_file} .img).ext4
	simg2img $rootfs_desktop_file $rootfs_desktop_file_ext4
	rootfs_desktop_file=$rootfs_desktop_file_ext4
elif [[ $rootfs_desktop_file_type = *"ext4 filesystem data"* ]]; then
	true
else
	echo "ERROR: ROOTFS_IMAGE type isn't supported: $rootfs_file_type"
	exit 1
fi
if [[ $rootfs_file_type = *"Android sparse image"* ]]; then
	rootfs_file_ext4=out/$(basename ${rootfs_file} .img).ext4
	simg2img $rootfs_file $rootfs_file_ext4
	rootfs_file=$rootfs_file_ext4
elif [[ $rootfs_file_type = *"ext4 filesystem data"* ]]; then
	true
else
	echo "ERROR: ROOTFS_IMAGE type isn't supported: $rootfs_file_type"
	exit 1
fi

# Populate firmware and modules
if [[ ! -z "$modules_file" ]]; then
	modules_file_type=$(file $modules_file)
	copy_archive_to_rootfs "$modules_file" "$modules_file_type" "$ramdisk_file" "$ramdisk_file_type"
	copy_archive_to_rootfs "$modules_file" "$modules_file_type" "$rootfs_file" "$rootfs_file_type"
	copy_archive_to_rootfs "$modules_file" "$modules_file_type" "$rootfs_desktop_file" "$rootfs_desktop_file_type"
fi
if [[ ! -z "${firmware_file}" ]]; then
	firmware_tmp_dir="firmware_tmp"
	firmware_tmp_file="firmware_tmp.tar.gz"

	mkdir -p $firmware_tmp_dir
	for firmware in ${firmware_file}; do
		dpkg-deb -x $firmware $firmware_tmp_dir
	done
	cd $firmware_tmp_dir
	tar -czpf ../$firmware_tmp_file *
	cd ../

	ffile_type=$(file $firmware_tmp_file)
	copy_archive_to_rootfs "$firmware_tmp_file" "$ffile_type" "$ramdisk_file" "$ramdisk_file_type"
	remove_unused_firmware "$ramdisk_file" "$ramdisk_file_type"
	copy_archive_to_rootfs "$firmware_tmp_file" "$ffile_type" "$rootfs_file" "$rootfs_file_type"
	copy_archive_to_rootfs "$firmware_tmp_file" "$ffile_type" "$rootfs_desktop_file" "$rootfs_desktop_file_type"

	rm -rf $firmware_tmp_dir $firmware_tmp_file 
fi

# If rootfs was Android sparse image trasform from ext4
if [[ $rootfs_desktop_file_type = *"Android sparse image"* ]]; then
	rootfs_desktop_file_img=out/$(basename $rootfs_desktop_file .ext4).img
	img2simg $rootfs_desktop_file $rootfs_desktop_file_img
	rm $rootfs_desktop_file
	rootfs_desktop_file=$rootfs_desktop_file_img
fi
if [[ $rootfs_file_type = *"Android sparse image"* ]]; then
	rootfs_file_img=out/$(basename $rootfs_file .ext4).img
	img2simg $rootfs_file $rootfs_file_img
	rm $rootfs_file
	rootfs_file=$rootfs_file_img
fi


# Compress ramdisk/rootfs images
if [[ $ramdisk_comp = "gz" ]]; then
	${GZ} $ramdisk_file
	ramdisk_file="$ramdisk_file".gz
	ramdisk_file_type=$(file $ramdisk_file)
	ramdisk_comp=""
fi
if [[ $rootfs_comp = "gz" ]]; then
	${GZ} $rootfs_file
	rootfs_file="$rootfs_file".gz
	rootfs_file_type=$(file $rootfs_file)
	rootfs_comp=""
fi
if [[ $rootfs_desktop_comp = "gz" ]]; then
	${GZ} $rootfs_desktop_file
	rootfs_desktop_file="$rootfs_desktop_file".gz
	rootfs_desktop_file_type=$(file $rootfs_desktop_file)
	rootfs_desktop_comp=""
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

# Overlay ramdisk to install tools, artifacts, etc
if [[ ! -z "${BOOTRR_GIT_REPO}" ]]; then
	overlayed_ramdisk_file="out/$(overlay_ramdisk_from_git "${BOOTRR_GIT_REPO}" "${BOOTRR_GIT_BRANCH}")"
	ramdisk_file=$overlayed_ramdisk_file
fi

# Create boot image (bootrr), uses systemd autologin root
boot_file=boot-${KERNEL_FLAVOR}-${KERNEL_VERSION}-${BUILD_NUMBER}-${MACHINE}.img
skales-mkbootimg \
	--kernel $kernel_file \
	--ramdisk $overlayed_ramdisk_file \
	--output out/$boot_file \
	$dt_mkbootimg_arg \
	--pagesize "${BOOTIMG_PAGESIZE}" \
	--base "${BOOTIMG_BASE}" \
	--ramdisk_base "${RAMDISK_BASE}" \
	--cmdline "root=/dev/ram0 init=/sbin/init rw console=tty0 console=${SERIAL_CONSOLE},115200n8 earlycon debug net.ifnames=0 ${KERNEL_CMDLINE_APPEND}"

# Create boot image (functional), sdm845-mtp requires an initramfs to mount the rootfs and then
# exec switch_rootfs, use the same method in other boards too
boot_rootfs_file=boot-rootfs-${KERNEL_FLAVOR}-${KERNEL_VERSION}-${BUILD_NUMBER}-${MACHINE}.img
init_file=init
sed -e "s|__ROOTFS_PARTITION__|${ROOTFS_PARTITION}|g" < configs/lt-qcom-linux-test/initscripts/init-rootfs.sh > ./$init_file
chmod +x ./$init_file
overlayed_ramdisk_file="out/$(overlay_ramdisk_from_file "$init_file" "init_rootfs")"
rm -f $init_file

skales-mkbootimg \
	--kernel $kernel_file \
	--ramdisk $overlayed_ramdisk_file \
	--output out/$boot_rootfs_file \
	$dt_mkbootimg_arg \
	--pagesize "${BOOTIMG_PAGESIZE}" \
	--base "${BOOTIMG_BASE}" \
	--ramdisk_base "${RAMDISK_BASE}" \
	--cmdline "root=/dev/ram0 init=/init rw console=tty0 console=${SERIAL_CONSOLE},115200n8 earlycon debug net.ifnames=0 ${KERNEL_CMDLINE_APPEND}"

echo BOOT_FILE=$boot_file >> builders_out_parameters
echo BOOT_ROOTFS_FILE=$boot_rootfs_file >> builders_out_parameters
echo ROOTFS_FILE="$(basename $rootfs_file)" >> builders_out_parameters
echo ROOTFS_DESKTOP_FILE="$(basename $rootfs_desktop_file)" >> builders_out_parameters

# Kernel CI parameters in LAVA jobs
echo KERNEL_IMAGE="$(basename $KERNEL_IMAGE_URL)" >> builders_out_parameters
echo KERNEL_DT="$(basename $KERNEL_DT_URL)" >> builders_out_parameters
echo KERNEL_CI_PLATFORM="${KERNEL_CI_PLATFORM}" >> builders_out_parameters
echo KERNEL_CI_MACH="${KERNEL_CI_MACH}" >> builders_out_parameters
echo RAMDISK_URL="${RAMDISK_URL}" >> builders_out_parameters
echo KERNEL_DT_URL="${KERNEL_DT_URL}" >> builders_out_parameters

ls -l out/
