#!/bin/bash

# requirements:
# apt install libguestfs-tools

sudo guestfish --rw -a $1 << 'EOF'
 run
 list-filesystems
 mount /dev/sda1 /
 cat /loader.0/entries/ostree-1-fedora-iot.conf | sed 's/options/options console=ttyS0,115200/'  > /tmp/ostree-1-fedora-iot.conf
 copy-in  /tmp/ostree-1-fedora-iot.conf /loader.0/entries/
 cat /loader.0/entries/ostree-1-fedora-iot.conf

 !mkdir -p deploy
 tar-out / - | gzip >  deploy/boot.tar.gz
 umount /

 mount /dev/sda2 /
 tar-out / - | gzip >  deploy/rootfs.tar.gz
 umount /
EOF

cd deploy
tar -xzf boot.tar.gz --strip-components=3 --wildcards --no-anchored 'vmlinuz*'
tar -xzf boot.tar.gz --strip-components=3 --wildcards --no-anchored 'initramfs*'
virt-make-fs --size=+200M rootfs.tar.gz rootfs.ext2.img
pigz rootfs.ext2.img
cd -
