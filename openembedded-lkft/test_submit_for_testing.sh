#!/bin/bash

set -e

virtualenv .venv
source .venv/bin/activate
pip install Jinja2 requests urllib3 ruamel.yaml

export BASE_URL=http://snapshots.linaro.org
export PUB_DEST=openembedded/lkft/morty/hikey/rpb/linux-mainline/346
export EXT4_IMAGE_URL="${BUILD_LOCATION}/${EXT4_IMAGE_FILENAME}"
export BOOT_URL=${BASE_URL}/${PUB_DEST}/boot-0.0+AUTOINC+06e4def583-fb1158a365-r0-hikey-20171012090440-346.uefi.img
export DTB_URL=${BASE_URL}/${PUB_DEST}/junor2.dtb
export HDD_URL=${BASE_URL}/${PUB_DEST}/rpb-console-image-intel-core2-32-20180212181859-651.hddimg
export BUILD_ID=346
export BUILD_NUMBER=346
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
export KERNEL_URL=${BASE_URL}/${PUB_DEST}/Image--4.13+git0+ff5abbe799-r0-hikey-20171012090440-346.bin
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
export NFSROOTFS_URL=${BASE_URL}/${PUB_DEST}/rpb-console-image-hikey-20171012090440-346.rootfs.tar.xz
export QA_REPORTS_TOKEN=qa-reports-token
export QA_SERVER=https://qa-reports.linaro.org
export QA_SERVER_PROJECT=linux-mainline-oe
export RECOVERY_IMAGE_URL=${BASE_URL}/${PUB_DEST}/juno-oe-uboot.zip
export SKIP_LAVA=
export SRCREV_kernel=ff5abbe799e29099695cb8b5b2f198dd8b8bdf26
export SYSTEM_URL=${BASE_URL}/${PUB_DEST}/rpb-console-image-hikey-20171012090440-346.rootfs.img.gz
export BUILD_NAME="openembedded-lkft-linux-mainline"
export LAVA_JOB_PRIORITY="medium"
export QA_SERVER="http://localhost:8000"
export QA_REPORTS_TOKEN="secret"
export DEVICE_TYPE="x86"
export KSELFTEST_SKIPLIST="pstore"
export QA_BUILD_VERSION=${KERNEL_DESCRIBE}

export DRY_RUN=true

for device in $(ls lava-job-definitions/devices); do
    export DEVICE_TYPE=$device
    bash submit_for_testing.sh
done

# cleanup virtualenv
deactivate
rm -rf .venv
