#!/bin/bash

export image_name=$(mktemp -u -p'cloud-image' | sed -e 's+/+-+g')
export mountpoint=$(mktemp -d /tmp/${image_name}.XXXXXX)

sudo apt-get update
sudo apt-get install -y git cpio qemu-utils virtinst libvirt-clients iproute2 \
             libglib2.0-bin intltool libvirt-glib-1.0-dev libgtk-3-dev python-ipaddr \
             gobject-introspection  python-libguestfs gir1.2-gspell-1 \
			 qemu-efi libgtksourceview2.0-dev libosinfo-1.0-0 pigz
sudo apt-get install -y python3-gi python3-libvirt python3-libxml2 python3-requests

git clone https://github.com/virt-manager/virt-manager.git virt-manager.git
cd virt-manager.git
git checkout v2.2.1
sudo ./setup.py install
cd -
sudo virt-install --version

default_gw=$(ip route show default 0.0.0.0/0 | cut -d' ' -f3)
sudo sed -i "/^uri_default/d" /etc/libvirt/libvirt.conf
echo "uri_default = \"qemu+tcp://${default_gw}/system\"" | sudo tee -a /etc/libvirt/libvirt.conf

# create loop device for kpartx
if ! [ -b /dev/loop0 ]; then
	mkdir /dev/loop0 b 7 0
fi

virt-host-validate

sudo virsh pool-list --all
sudo virsh net-list --all

set -ex

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
  cd ${WORKSPACE}
  sudo virsh vol-delete --pool default ${image_name}.img || true
  sudo virsh destroy ${image_name} || true
  sudo virsh undefine --nvram ${image_name} || true
  sudo umount ${mountpoint} || true
  sudo kpartx -dv ${image_name}.img || true
  sudo rm -rf ${mountpoint} || true
  sudo rm -f ${image_name}.img
}

wget -q http://git-us.linaro.org/ci/job/configs.git/plain/fedora-iot/f30-iot-aarch64.ks -O f30-iot.ks

sudo virt-install \
  --name ${image_name} \
  --disk pool=default,size=8,format=raw \
  --network network=default, \
  --os-variant fedora22 \
  --ram 4096 --arch aarch64 \
  --location https://dl.fedoraproject.org/pub/alt/iot/30/IoT/aarch64/os/,kernel=images/pxeboot/vmlinuz,initrd=images/pxeboot/initrd.img \
  --initrd-inject="f30-iot.ks" --extra-args "ks=http://git-us.linaro.org/ci/job/configs.git/plain/fedora-iot/f30-iot.ks earlycon=pl011,0x3f201000 console=ttyAMA0" \
  --boot loader=/usr/share/AAVMF/AAVMF_CODE.fd,loader_ro=yes,loader_type=pflash,nvram_template=/usr/share/AAVMF/AAVMF_VARS.fd,loader_secure=no \
  --noreboot

set +ex
# Fedora IoT has a bug when unmounting swap during the reboot
# rely on a timeout to break the job until this is fixes
# while [ true ]; do
timeout=1800
while [ $timeout -gt 0 ]; do
  sleep 1
  vm_running=$(sudo virsh list --name --state-running | grep "^${image_name}" | wc -l)
  [ "${vm_running}" -eq "0" ] && break
  timeout=$((timeout-1))
done
set -ex

sudo virsh list --all

mkdir -p out
cp f30-iot.ks out/

sudo cp -a /var/lib/libvirt/images/${image_name}.img .

sudo virsh vol-download --pool default --vol ${image_name}.img --file ${image_name}.img

sudo qemu-img convert -c -O qcow2 ${image_name}.img out/fedora-iot-rp-cloud-image_aarch64.qcow2
pigz -9 out/fedora-iot-rp-cloud-image_aarch64.qcow2

sudo chown -R buildslave:buildslave out
