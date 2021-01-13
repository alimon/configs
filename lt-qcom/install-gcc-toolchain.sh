#!/bin/bash

if [ -z "${ARCH}" ]; then
	ARCH=arm64
fi
if [ "${TOOLCHAIN_ARCH}" ]; then
	ARCH="${TOOLCHAIN_ARCH}"
fi

toolchain_url_arm=https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/10.2-2020.11/binrel/gcc-arm-10.2-2020.11-x86_64-arm-none-eabi.tar.xz
toolchain_url_arm64=https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/10.2-2020.11/binrel/gcc-arm-10.2-2020.11-x86_64-aarch64-none-linux-gnu.tar.xz
toolchain_url=toolchain_url_$ARCH
toolchain_url=${!toolchain_url}

export tcdir=${HOME}/srv/toolchain
export tcbindir="${tcdir}/$(basename $toolchain_url .tar.xz)/bin"
if [ ! -d "${tcbindir}" ]; then
	wget -q "${toolchain_url}"
	sudo mkdir -p "${tcdir}"
	sudo tar -xf "$(basename ${toolchain_url})" -C "${tcdir}"
fi

export PATH=$tcbindir:$PATH

echo tcbindir="${tcbindir}" > gcc_toolchain_env
