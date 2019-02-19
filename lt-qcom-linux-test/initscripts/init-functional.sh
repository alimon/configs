#!/bin/sh

HOME=/root
PATH=/sbin:/bin:/usr/sbin:/usr/bin
export HOME PATH

do_mount_fs() {
	grep -qa "$1" /proc/filesystems || return
	test -d "$2" || mkdir -p "$2"
	mount -t "$1" "$1" "$2"
}

do_mknod() {
	test -e "$1" || mknod "$1" "$2" "$3" "$4"
}

rescue_shell() {
	echo "Failed to mount rootfs (__ROOTFS_PARTITION__), executing rescue shell..."
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

if [ ! -b "__ROOTFS_PARTITION__" ]; then
	echo "Waiting for root device __ROOTFS_PARTITION__ ..."
	while [ ! -b "__ROOTFS_PARTITION__" ]; do
		sleep 1s
	done;
fi

mkdir -p /rootfs
mount -o ro __ROOTFS_PARTITION__ /rootfs || rescue_shell

umount /proc
umount /sys
umount /dev

echo "All done. Switching to real root."
exec switch_root /rootfs /sbin/init
