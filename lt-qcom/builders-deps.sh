#!/bin/bash

set -ex

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
	echo "INFO: apt update error - try again in a moment"
	sleep 15
	sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi

pkg_list="tar gzip pigz cpio xz-utils wget skales e2fsprogs e2tools simg2img img2simg python-pip curl dpkg ccache bc kmod cpio libssl-dev"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
	echo "INFO: apt install error - try again in a moment"
	sleep 15
	sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

export GZ=pigz

rm -rf configs
git clone --depth 1 http://git.linaro.org/ci/job/configs.git
pip install --user python-dateutil beautifulsoup4
