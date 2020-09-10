#!/bin/bash

# This 'test' script generates all job templates from lava-job-definitions,
# verifies that they are valid YAML, and saves them all to ./tmp/. When making
# lava job template changes in lava-job-definitions, run this beforehand, save
# /tmp to a new path, and then run it after and diff the directories to see the
# effects the change had on the job definitions.
#
# These generated templates can also be verified by lava by using the following
# commandline, which requires lavacli to be configured with authentication
# against some LAVA host.
#
#    drue@xps:~/src/configs/openembedded-lkft$ rm -rf tmp && ./test_submit_for_testing.sh && for file in $(find tmp -name '*.yaml'); do echo $file && lavacli -i therub jobs validate $file || break; done

set -e

virtualenv --python=$(which python2) .venv
source .venv/bin/activate
pip install Jinja2 requests urllib3 ruamel.yaml

export BUILD_ID=346
export BUILD_NUMBER=346
export BASE_URL=http://snapshots.linaro.org
export PUB_DEST=openembedded/lkft/morty/hikey/rpb/linux-mainline/${BUILD_NUMBER}
export BOOOT_IMG=boot-Image-hikey-20171012090440-346.uefi.img
export KERNEL_IMG=Image-gz-hikey-20171012090440-346.bin
export MODULES_TGZ=modules--hikey-20171012090440-346.tgz
export DTB_IMG=Image-gz-hikey-20171012090440-346.dtb
export ROOTFS_IMG=rpb-console-image-hikey-20171012090440-346.rootfs.img.gz
export ROOTFS_EXT4=rpb-console-image-hikey-20171012090440-346.rootfs.ext4.gz
export ROOTFS_TARXZ_IMG=rpb-console-image-hikey-20171012090440-346.rootfs.tar.xz
export HDD_IMG=rpb-console-image-hikey-20171012090440-346.rootfs.hddimg
export BOOT_URL=${BASE_URL}/${PUB_DEST}/${BOOT_IMG}
export DTB_URL=${BASE_URL}/${PUB_DEST}/${DTB_IMG}
export KERNEL_URL=${BASE_URL}/${PUB_DEST}/${KERNEL_IMG}
export MODULES_URL=${BASE_URL}/${PUB_DEST}/${MODULES_TGZ}
export EXT4_IMAGE_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_EXT4}
export NFSROOTFS_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_TARXZ_IMG}
export HDD_URL=${BASE_URL}/${PUB_DEST}/${HDD_IMG}
export SYSTEM_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_IMG}
export BUILD_URL="https://ci.linaro.org/job/openembedded-lkft-linux-mainline/DISTRO=rpb,MACHINE=hikey,label=docker-stretch-amd64/346/"
export JOB_BASE_NAME="DISTRO=rpb,MACHINE=hikey,label=docker-stretch-amd64"
export JOB_NAME="openembedded-lkft-linux-mainline/DISTRO=rpb,MACHINE=hikey,label=docker-stretch-amd64"
export JOB_URL="https://ci.linaro.org/job/openembedded-lkft-linux-mainline/DISTRO=rpb,MACHINE=hikey,label=docker-stretch-amd64/"
export KERNEL_BRANCH=master
export KERNEL_COMMIT=ff5abbe799e29099695cb8b5b2f198dd8b8bdf26
export KERNEL_CONFIG_URL=${BASE_URL}/${PUB_DEST}/config
export KERNEL_DEFCONFIG_URL=${BASE_URL}/${PUB_DEST}/defconfig
export KERNEL_DESCRIBE=v4.14-rc4-84-gff5abbe799e2
export KERNEL_RECIPE=linux-hikey-mainline
export KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
export KERNEL_VERSION=git
export KERNEL_VERSION_OVERRIDE=mainline
export KSELFTEST_PATH="/opt/"
export KSELFTESTS_URL=https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.13.tar.xz
export KSELFTESTS_VERSION=4.13
export KSELFTESTS_REVISION=g4.13
export KSELFTESTS_NEXT_URL=git://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
export KSELFTESTS_NEXT_VERSION=4.13+gitAUTOINC+49827b977a
export LAVA_SERVER=https://lkft.validation.linaro.org/RPC2/
export LIBHUGETLBFS_REVISION=e44180072b796c0e28e53c4d01ef6279caaa2a99
export LIBHUGETLBFS_URL=git://github.com/libhugetlbfs/libhugetlbfs.git
export LIBHUGETLBFS_VERSION=2.20
export LTP_REVISION=e671f2a13c695bbd87f7dfec2954ca7e3c43f377
export LTP_URL=git://github.com/linux-test-project/ltp.git
export LTP_VERSION=20170929
export MACHINE=hikey
export MAKE_KERNELVERSION=4.14.0-rc4
export MANIFEST_BRANCH=morty
export QA_REPORTS_TOKEN=qa-reports-token
export QA_SERVER=https://qa-reports.linaro.org
export QA_SERVER_PROJECT=linux-mainline-master
export RECOVERY_IMAGE_URL=${BASE_URL}/${PUB_DEST}/juno-oe-uboot.zip
export SKIP_LAVA=
export SRCREV_kernel=ff5abbe799e29099695cb8b5b2f198dd8b8bdf26
export BUILD_NAME="openembedded-lkft-linux-mainline"
export LAVA_JOB_PRIORITY="50"
export SANITY_LAVA_JOB_PRIORITY="55"
export QA_SERVER="http://localhost:8000"
export QA_REPORTS_TOKEN="secret"
export DEVICE_TYPE="x86"
export KSELFTEST_SKIPLIST="pstore"
export QA_BUILD_VERSION=${KERNEL_DESCRIBE}
export TOOLCHAIN="arm-linaro-linux-gnueabi linaro-6.2"

export DRY_RUN=true

for device in hi6220-hikey i386 x86 juno-r2 x15 dragonboard-410c; do
    export DEVICE_TYPE=$device
    bash submit_for_testing.sh
done

# cleanup virtualenv
deactivate
rm -rf .venv
