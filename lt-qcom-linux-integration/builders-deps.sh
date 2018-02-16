#!/bin/bash

set -e

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
	echo "INFO: apt update error - try again in a moment"
	sleep 15
	sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi

pkg_list="tar gzip pigz cpio xz-utils wget skales e2fsprogs simg2img img2simg python-pip"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
	echo "INFO: apt install error - try again in a moment"
	sleep 15
	sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

sudo mount -t tmpfs tmpfs /tmp

export GZ=pigz

set -ex
