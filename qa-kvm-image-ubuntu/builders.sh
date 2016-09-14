#!/bin/bash

export image_name=ubuntu-kvm-image

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
  cd ${WORKSPACE}
  sudo virsh destroy ${image_name} || true
  sudo virsh undefine ${image_name} || true
  sudo rm -f /var/lib/libvirt/images/${image_name}.qcow2
  rm -rf out
}

sudo apt-get -q=2 update
sudo apt-get -q=2 -y install qemu-utils virtinst libguestfs-tools pigz

default_gw=$(ip route show default 0.0.0.0/0 | cut -d' ' -f3)
sudo sed -i "/^uri_default/d" /etc/libvirt/libvirt.conf
echo "uri_default = \"qemu+tcp://${default_gw}/system\"" | sudo tee -a /etc/libvirt/libvirt.conf

sudo virsh pool-list --all
sudo virsh net-list --all

wget -q https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/qa-kvm-image-ubuntu/preseed.cfg -O preseed.cfg

sudo virt-install \
  --name ${image_name} \
  --initrd-inject preseed.cfg \
  --extra-args "interface=auto noshell auto=true DEBIAN_FRONTEND=text" \
  --disk=path=/var/lib/libvirt/images/${image_name}.qcow2,bus=virtio,size=4,format=qcow2 \
  --memory 2048 \
  --location http://archive.ubuntu.com/ubuntu/dists/xenial/main/installer-amd64/ \
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
mv preseed.cfg out/ubuntu-xenial-amd64-preseed.cfg
sudo qemu-img convert -O raw /var/lib/libvirt/images/${image_name}.qcow2 out/${image_name}.img
sudo chown -R buildslave:buildslave out
time pigz -9 out/${image_name}.img
