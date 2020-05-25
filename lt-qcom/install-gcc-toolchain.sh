#!/bin/bash

toolchain_url_arm=http://releases.linaro.org/components/toolchain/binaries/6.3-2017.02/arm-linux-gnueabihf/gcc-linaro-6.3.1-2017.02-x86_64_arm-linux-gnueabihf.tar.xz
toolchain_url_arm64=http://releases.linaro.org/components/toolchain/binaries/6.3-2017.02/aarch64-linux-gnu/gcc-linaro-6.3.1-2017.02-x86_64_aarch64-linux-gnu.tar.xz
toolchain_url=toolchain_url_$ARCH
toolchain_url=${!toolchain_url}

tcdir=${HOME}/srv/toolchain
tcbindir="${tcdir}/$(basename $toolchain_url .tar.xz)/bin"
if [ ! -d "${tcbindir}" ]; then
	wget -q "${toolchain_url}"
	mkdir -p "${tcdir}"
	tar -xf "$(basename ${toolchain_url})" -C "${tcdir}"
fi

echo tcbindir="${tcbindir}" > gcc_toolchain_env
