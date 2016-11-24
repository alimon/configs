#!/bin/bash

export image_name=centos7-cloud-image

sudo apt-get -q=2 update
sudo apt-get -q=2 install -y --no-install-recommends qemu-utils virtinst libguestfs-tools libvirt-bin

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
  sudo virsh destroy ${image_name} || true
  sudo virsh undefine ${image_name} || true
  sudo rm -f /var/lib/libvirt/images/${image_name}.qcow2 ${image_name}.qcow2
}

wget -q https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/leg-cloud-image/centos/centos7-aarch64.ks -O centos7-aarch64.ks

sudo virt-install \
  --name ${image_name} \
  --initrd-inject centos7-aarch64.ks \
  --extra-args "ks=file:/centos7-aarch64.ks" \
  --disk=pool=default,size=10,format=qcow2,bus=virtio \
  --memory 2048 \
  --location http://mirror.centos.org/altarch/7/os/aarch64/ \
  --noreboot

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
mv centos7-aarch64.ks out/
sudo cp -a /var/lib/libvirt/images/${image_name}.qcow2 .
sudo qemu-img convert -c -O qcow2 ${image_name}.qcow2 out/${image_name}.qcow2
# extract kernel and initramfs from image
# --unversioned-names may be handy to get vmlinuz/initrd.img names if needed
sudo LIBGUESTFS_BACKEND=direct virt-copy-out -a ${image_name}.qcow2 /boot/ .
sudo cp -a boot/*-reference.*.aarch64* out/
sudo chown -R buildslave:buildslave out
