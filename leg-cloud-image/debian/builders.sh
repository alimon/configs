#!/bin/bash

export image_name=debian-cloud-image
export mountpoint=$(mktemp -d /tmp/${image_name}.XXXXXX)

sudo apt-get -q=2 update
sudo apt-get -q=2 install -y --no-install-recommends cpio qemu-utils virtinst libvirt-bin

default_gw=$(ip route show default 0.0.0.0/0 | cut -d' ' -f3)
sudo sed -i "/^uri_default/d" /etc/libvirt/libvirt.conf
echo "uri_default = \"qemu+tcp://${default_gw}/system\"" | sudo tee -a /etc/libvirt/libvirt.conf

virt-host-validate

sudo virsh pool-list --all
sudo virsh net-list --all

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
  cd ${WORKSPACE}
  sudo virsh vol-delete --pool default ${image_name}.qcow2 || true
  sudo virsh destroy ${image_name} || true
  sudo virsh undefine ${image_name} || true
  sudo umount ${mountpoint} || true
  sudo kpartx -dv /dev/nbd0 || true
  sudo qemu-nbd --disconnect /dev/nbd0 || true
  sudo rm -rf ${mountpoint} || true
  sudo rm -f ${image_name}.qcow2
}

wget -q https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/leg-cloud-image/debian/preseed.cfg -O preseed.cfg

#
# address.type=virtio-mmio forces all devices (storage, network) to be mmio instead of pci
# Debian/jessie 3.16 kernel does not recognize virtio pci network card
#
sudo virt-install \
  --name ${image_name} \
  --initrd-inject preseed.cfg \
  --extra-args "interface=auto noshell auto=true DEBIAN_FRONTEND=text" \
  --disk=pool=default,bus=virtio,size=10,format=qcow2 \
  --network=network=default,address.type=virtio-mmio \
  --memory 2048 \
  --location http://ftp.debian.org/debian/dists/oldstable/main/installer-arm64/ \
  --noreboot \
  --debug

set +ex
while [ true ]; do
  sleep 1
  vm_running=$(sudo virsh list --name --state-running | grep "^${image_name}" | wc -l)
  [ "${vm_running}" -eq "0" ] && break
done
set -ex

sudo virsh list --all
sudo virsh pool-list --all
sudo virsh net-list --all

mkdir out
mv preseed.cfg out/debian-jessie-arm64-preseed.cfg
# virsh vol-download is slow - copy from a mounted volume
sudo cp -a /var/lib/libvirt/images/${image_name}.qcow2 .
# extract kernel and initramfs from image
sudo qemu-nbd --connect=/dev/nbd0 ${image_name}.qcow2
for device in $(sudo kpartx -avs /dev/nbd0 | cut -d' ' -f3); do
  partition=$(echo ${device} | cut -d'p' -f2)
  [ "${partition}" = "2" ] && sudo mount /dev/mapper/${device} ${mountpoint}
done
cp -a ${mountpoint}/boot/*-arm64 out/
sudo qemu-img convert -c -O qcow2 ${image_name}.qcow2 out/${image_name}.qcow2
sudo chown -R buildslave:buildslave out
