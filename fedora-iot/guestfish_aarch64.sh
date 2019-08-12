#!/bin/bash

# requirements:
# apt install libguestfs-tools

sudo guestfish --rw -a $1 << 'EOF'
 run
 list-filesystems

 !mkdir -p deploy

 mount /dev/sda1 /
 tar-out / - | gzip >  deploy/boot_efi.tar.gz
 umount /

 mount /dev/sda2 /
 tar-out / - | gzip >  deploy/boot.tar.gz
 umount /

 mount /dev/sda3 /
 tar-out / - | gzip >  deploy/rootfs.tar.gz
 umount /

EOF

cd deploy
tar -xzf boot.tar.gz --strip-components=3 --wildcards --no-anchored 'vmlinuz*'
tar -xzf boot.tar.gz --strip-components=3 --wildcards --no-anchored 'initramfs*'
virt-make-fs --size=+200M rootfs.tar.gz rootfs.ext2.img
pigz rootfs.ext2.img
cd -
