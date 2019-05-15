#!/bin/bash

set -ex

virtualenv --python=$(which python2) .venv
source .venv/bin/activate
pip install Jinja2 requests urllib3 ruamel.yaml

export BUILD_NUMBER=296
export PUBLISH_SERVER=https://snapshots.linaro.org/

export KERNEL_CI_MACH=qcom
export KERNEL_CI_PLATFORM=qcs404-evb-1000
export KERNEL_DT=qcs404-evb-1000.dtb
export KERNEL_DT_URL=https://storage.kernelci.org/qcom-lt/integration-linux-qcomlt/v5.1-243-g5f45ef7de008/arm64/defconfig/gcc-7/dtbs
export KERNEL_FLAVOR=linux-integration
export KERNEL_IMAGE=Image
export KERNEL_IMAGE_URL=https://storage.kernelci.org/qcom-lt/integration-linux-qcomlt/v5.1-243-g5f45ef7de008/arm64/defconfig/gcc-7/Image
export KERNEL_MODULES_URL=https://storage.kernelci.org/qcom-lt/integration-linux-qcomlt/v5.1-243-g5f45ef7de008/arm64/defconfig/gcc-7/modules.tar.xz
export KERNEL_VERSION=v5.1-243-g5f45ef7de008
export RAMDISK_URL=https://snapshots.linaro.org/member-builds/qcomlt/testimages/arm64/97/initramfs-test-image-qemuarm64-20190510103406-97.rootfs.cpio.gz

export QA_SERVER="http://localhost:8000"
export QA_REPORTS_TOKEN="secret"
export LAVA_SERVER=https://validation.linaro.org/RPC2/
export QA_SERVER_PROJECT="linux-integration"
export QCOMLT_KERNELCI_TOKEN=""

export DRY_RUN="--dry-run "

export MACHINE="qcs404-evb-1000"
export PUB_DEST=member-builds/qcomlt/linux-integration/${MACHINE}/296/
export BOOT_FILE=boot-linux-integration-v5.1-243-g5f45ef7de008-296-qcs404-evb-1000.img
export BOOT_ROOTFS_FILE=boot-rootfs-linux-integration-v5.1-243-g5f45ef7de008-296-qcs404-evb-1000.img
export ROOTFS_FILE=rpb-console-image-test-qemuarm64-20190510103406-97.rootfs.img.gz
bash submit_for_testing.sh

export MACHINE="apq8016-sbc"
export PUB_DEST=member-builds/qcomlt/linux-integration/${MACHINE}/296/
export BOOT_FILE=boot-linux-integration-v5.1-243-g5f45ef7de008-296-apq8016-sbc.img
export BOOT_ROOTFS_FILE=boot-rootfs-linux-integration-v5.1-243-g5f45ef7de008-296-apq8016-sbc.img
export ROOTFS_FILE=rpb-console-image-test-qemuarm64-20190510103406-97.rootfs.img.gz
bash submit_for_testing.sh

# cleanup virtualenv
deactivate
rm -rf .venv
