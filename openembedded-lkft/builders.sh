#!/bin/bash

set -ex

# workaround: EDK2 is confused by the long path used during the build
# and truncate files name expected by VfrCompile
sudo mkdir -p /srv/oe
sudo chown buildslave:buildslave /srv/oe
cd /srv/oe

# Initialize repo if not done already
export MANIFEST_URL=${MANIFEST_URL:-https://github.com/96boards/oe-rpb-manifest.git}
repo init -u ${MANIFEST_URL} -b ${MANIFEST_BRANCH}

# Link to shared downloads on persistent disk
mkdir -p ${HOME}/srv/oe/downloads ${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH}
mkdir -p build
ln -s ${HOME}/srv/oe/downloads
ln -s ${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH} sstate-cache

repo sync --force-sync

# Save manifest
cp .repo/manifest.xml source-manifest.xml
repo manifest -r -o pinned-manifest.xml
MANIFEST_COMMIT=$(cd .repo/manifests && git rev-parse --short HEAD)

# record changes since last build, if available
BASE_URL=http://snapshots.linaro.org
if wget -q ${BASE_URL}${PUB_DEST/\/${BUILD_NUMBER}\//\/latest\/}/pinned-manifest.xml -O pinned-manifest-latest.xml; then
    repo diffmanifests ${PWD}/pinned-manifest-latest.xml ${PWD}/pinned-manifest.xml > manifest-changes.txt
else
    echo "Latest build published does not have pinned-manifest.xml. Skipping diff report."
fi

# the setup-environment will create auto.conf and site.conf
# make sure we get rid of old config.
# let's remove the previous TMPDIR as well.
# we want to preserve build/buildhistory though.
rm -rf conf build/conf build/tmp-*/

# Accept EULA if/when needed
export EULA_dragonboard410c=1
source setup-environment build

########## vvv DISTRO DEPENDANT vvv ##########
if [ "${DISTRO}" = "rpb" ]; then

# Add job BUILD_NUMBER to output files names
cat << EOF >> conf/auto.conf
IMAGE_NAME_append = "-${BUILD_NUMBER}"
KERNEL_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
MODULE_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
DT_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
BOOT_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
EOF

# get build stats to make sure that we use sstate properly
cat << EOF >> conf/auto.conf
INHERIT += "buildstats buildstats-summary"
EOF

# Set the kernel to use
distro_conf=$(find ../layers/meta-rpb/conf/distro -name rpb.inc)
cat << EOF >> ${distro_conf}
PREFERRED_PROVIDER_virtual/kernel = "${KERNEL_RECIPE}"
EOF

case "${KERNEL_RECIPE}" in
  linux-hikey-aosp|linux-generic-android-common-o*|linux-generic-lsk*|linux-generic-stable*)
    cat << EOF >> ${distro_conf}
PREFERRED_VERSION_${KERNEL_RECIPE} = "${KERNEL_VERSION}+git%"
EOF
    ;;
esac

# Set the image types to use
cat << EOF >> ${distro_conf}
IMAGE_FSTYPES_remove = "ext4 iso wic"
EOF

# Set GCC to 7.x
cat << EOF >> ${distro_conf}
GCCVERSION = "7.%"
EOF

case "${KERNEL_RECIPE}" in
  linux-*-aosp|linux-*-android-*)
    cat << EOF >> ${distro_conf}
CONSOLE = "ttyFIQ0"
EOF
    ;;
esac

# Include additional recipes in the image
[ "${MACHINE}" = "am57xx-evm" -o "${MACHINE}" = "beaglebone" ] || extra_pkgs="numactl"
cat << EOF >> conf/local.conf
CORE_IMAGE_BASE_INSTALL_append = " kernel-selftests kselftests-mainline kselftests-next libhugetlbfs-tests ltp ${extra_pkgs}"
CORE_IMAGE_BASE_INSTALL_append = " python python-misc python-modules python-numpy python-pexpect python-pyyaml"
CORE_IMAGE_BASE_INSTALL_append = " git parted packagegroup-core-buildessential packagegroup-core-tools-debug tzdata"
EOF

# Override cmdline
cat << EOF >> conf/local.conf
CMDLINE_remove = "quiet"
EOF

# Remove recipes:
# - docker to reduce image size
cat << EOF >> conf/local.conf
RDEPENDS_packagegroup-rpb_remove = "docker"
EOF

cat << EOF >> conf/local.conf
SERIAL_CONSOLES_remove_intel-core2-32 = "115200;ttyPCH0"
SERIAL_CONSOLES_remove_intel-corei7-64 = "115200;ttyPCH0"
SERIAL_CONSOLES_append_dragonboard-410c = " 115200;ttyMSM1"
SERIAL_CONSOLES_append_hikey = " 115200;ttyAMA2"
EOF

# Enable lkft-metadata class
cat << EOF >> conf/local.conf
INHERIT += "lkft-metadata"
LKFTMETADATA_COMMIT = "1"
EOF

# Update kernel recipe SRCREV
echo "SRCREV_kernel_${MACHINE} = \"${SRCREV_kernel}\"" >> conf/local.conf

fi
########## ^^^ DISTRO DEPENDANT ^^^ ##########

# Remove systemd firstboot and machine-id file
# Backport serialization change from v234 to avoid systemd tty race condition
# Only on Morty
if [ "${MANIFEST_BRANCH}" = "morty" ]; then
  mkdir -p ../layers/meta-96boards/recipes-core/systemd/systemd
  wget -q http://people.linaro.org/~fathi.boudra/backport-v234-e266c06-v230.patch \
    -O ../layers/meta-96boards/recipes-core/systemd/systemd/backport-v234-e266c06-v230.patch

  cat << EOF >> ../layers/meta-96boards/recipes-core/systemd/systemd/e2fsck.conf
[options]
# This will prevent e2fsck from stopping boot just because the clock is wrong
broken_system_clock = 1
EOF

  cat << EOF >> ../layers/meta-96boards/recipes-core/systemd/systemd_%.bbappend
FILESEXTRAPATHS_prepend := "\${THISDIR}/\${PN}:"

SRC_URI += "\\
    file://backport-v234-e266c06-v230.patch \\
    file://e2fsck.conf \\
"

PACKAGECONFIG_remove = "firstboot"

do_install_append() {
    # Install /etc/e2fsck.conf to avoid boot stuck by wrong clock time
    install -m 644 -p -D \${WORKDIR}/e2fsck.conf \${D}\${sysconfdir}/e2fsck.conf

    rm -f \${D}\${sysconfdir}/machine-id
}

FILES_\${PN} += "\${sysconfdir}/e2fsck.conf "
EOF
fi

# The kernel (as of next-20181130) requires fold from the host
echo "HOSTTOOLS += \"fold\"" >> conf/local.conf

# add useful debug info
cat conf/{site,auto}.conf
cat ${distro_conf}

# Temporary sstate cleanup to get lkft metadata generated
[ "${DISTRO}" = "rpb" ] && bitbake -c cleansstate kselftests-mainline kselftests-next ltp libhugetlbfs

time bitbake ${IMAGES}
