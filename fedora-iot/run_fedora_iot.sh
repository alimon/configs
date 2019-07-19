#!/bin/sh

DRIVE="${FIMG:-Fedora-IoT-30-20190515.1.x86_64.raw}"

qemu-system-x86_64 -cpu host -enable-kvm \
	-net nic,model=virtio,macaddr=DE:AD:BE:EF:28:01 -net user \
	-m 1024 -boot d -serial mon:stdio -serial null -nographic  -drive format=raw,file=${DRIVE}
