#!/bin/bash

# Copies a test tarball overlay into the Android boot image ramdisk

set -ex

if [ $# -lt 2 ]; then
	echo "Usage: $0 <boot_file> <overlay_test_file>"
	exit 1
fi

boot_file=$1
overlay_file=$2

abootimg -x $boot_file
abootimg-unpack-initrd
tar -xvzf $overlay_file -C ramdisk
rm initrd.img
abootimg-pack-initrd
image_size=`du -b $boot_file | cut -f 1`
overlay_size=`gzip -l $overlay_file | tail -1 | awk '{print $2}'`
final_size=$(( $overlay_size + $image_size ))
abootimg -u $boot_file -r initrd.img -c "bootsize=$final_size"
