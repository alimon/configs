#!/bin/sh

HOME=/root
PATH=/sbin:/bin:/usr/sbin:/usr/bin
export HOME PATH

# Default global variables
DEFAULT_ROOTFS=__ROOTFS_PARTITION__

do_mount_fs() {
	grep -qa "$1" /proc/filesystems || return
	test -d "$2" || mkdir -p "$2"
	mount -t "$1" "$1" "$2"
}

do_mknod() {
	test -e "$1" || mknod "$1" "$2" "$3" "$4"
}

rescue_shell() {
	echo "Failed to mount rootfs ($ROOTFS), executing rescue shell..."
	export PS1="linaro-test [rc=$(echo \$?)]# "
	exec sh </dev/console >/dev/console 2>/dev/console
}

mkdir -p /proc
mount -t proc proc /proc

do_mount_fs sysfs /sys
do_mount_fs devtmpfs /dev

mkdir -p /run
mkdir -p /var/run
/sbin/udevd --daemon
/bin/udevadm trigger

do_mknod /dev/console c 5 1
do_mknod /dev/null c 1 3
do_mknod /dev/zero c 1 5

# Fetch the rootfs partition label information from the kernel cmdline.  If it
# is not available, use the default rootfs instead.  Match "PARTLABEL=
PARTLABEL=$(cat /proc/cmdline | grep -oE "PARTLABEL=[^ ]+" | cut -d'=' -f2)

if [ ! -z "$PARTLABEL" ]; then
	echo "Found rootfs partition label $PARTLABEL on cmdline."
	ROOTFS="/dev/disk/by-partlabel/$PARTLABEL"
else
	echo "No rootfs partition label found on cmdline."
	echo "Using default rootfs ($DEFAULT_ROOTFS) instead."
	ROOTFS=$DEFAULT_ROOTFS
fi

if [ ! -b "$ROOTFS" ]; then
	echo "Waiting for root device $ROOTFS ..."
	while [ ! -b "$ROOTFS" ]; do
		sleep 1s
	done;
fi

mkdir -p /rootfs
mount -o ro $ROOTFS /rootfs || rescue_shell

umount /proc
umount /sys
umount /dev

echo "All done. Switching to real root."
exec switch_root /rootfs /sbin/init
