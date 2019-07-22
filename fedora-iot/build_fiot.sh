#!/bin/sh

IMG="Fedora-IoT-30-20190515.1.x86_64.raw.xz"
URL="https://dl.fedoraproject.org/pub/alt/iot/30/IoT/x86_64/images"
wget -c ${URL}/${IMG}
xz -d ${IMG}

sudo losetup -P -f ${IMG}

LOOP="losetup |grep  ${IMG} |cut -d " " -f 1"
sudo mount /dev/${LOOP}p1 ./mnt/
sudo sed -i 's/options/options console=ttyS0,115200/' ./mnt/loader/entries/ostree-1-fedora-iot.conf

sudo mkdir  ./deploy
sudo find ./mnt -name vmlinu* -exec cp '{}' ./deploy/ \;
sudo find ./mnt -name initramf*.img -exec cp '{}' ./deploy/ \;
sudo umount ./mnt


sudo mount /dev/${LOOP}p2 ./mnt/
cd ./mnt
sudo tar -cpzf ../deploy/fiot-rootfs.tar.gz .
cd -
sudo losetup -d ${LOOP}

export FIMG="${IMG}"
sudo python ./create_fedora.py
sudo xz -c ${IMG} > ./deploy/${IMG}.xz

echo "build complete"

