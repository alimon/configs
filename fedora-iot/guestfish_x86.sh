#!/bin/bash

# requirements:
# apt install libguestfs-tools

sudo guestfish --rw -a Fedora-IoT-30-20190515.1.x86_64.raw << 'EOF'
 run
 list-filesystems
 mount /dev/sda1 /
 cat /loader.0/entries/ostree-1-fedora-iot.conf | sed 's/options/options gconsole=ttyS0,115200/'  > /tmp/ostree-1-fedora-iot.conf
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
cd -
