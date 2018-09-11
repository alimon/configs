#!/bin/bash

set -e

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="python-pip fai-server fai-setup-storage qemu-utils procps mtools pigz zip android-tools-fsutils android-tools-mkbootimg"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

set -ex

# Needed to use git commit/push on CI
git config --global user.name "Linaro CI"
git config --global user.email "ci_notify@linaro.org"
git config --global core.sshCommand "ssh -F ${HOME}/qcom.sshconfig"

cat << EOF > ${HOME}/qcom.sshconfig
Host git.linaro.org
    User git
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
EOF
chmod 0600 ${HOME}/qcom.sshconfig

# Build information
mkdir -p out
cat > out/HEADER.textile << EOF

h4. QCOM Landing Team - $BUILD_DISPLAY_NAME

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* OS flavour: $OS_FLAVOUR
* FAI: "$GIT_URL":$GIT_URL
* FAI commit: "$GIT_COMMIT":$GIT_URL/commit/?id=$GIT_COMMIT
EOF

sudo mount -t tmpfs tmpfs /tmp

# dumb utility to parse dpkg -l output
wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/lt-qcom-debian-images/debpkgdiff.py

# Record build log changes in git tree
git clone ssh://git.linaro.org/landing-teams/working/qualcomm/lt-ci.git -b debian/${PLATFORM_NAME}

for rootfs in ${ROOTFS}; do

    rootfs_sz=$(echo $rootfs | cut -f2 -d,)
    rootfs=$(echo $rootfs | cut -f1 -d,)

    sudo fai-diskimage -v --cspace $(pwd) \
         --hostname linaro-${rootfs} \
         -S ${rootfs_sz} \
         --class $(echo SAVECACHE,${OS_FLAVOUR},DEBIAN,LINARO,QCOM,${rootfs},${FAI_BOARD_CLASS},RAW | tr '[:lower:]' '[:upper:]') \
         /tmp/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.raw

    sudo cp /var/log/fai/linaro-${rootfs}/last/fai.log fai-${rootfs}.log
    if grep -E '^(ERROR:|WARNING: These unknown packages are removed from the installation list|Exit code task_)' fai-${rootfs}.log
    then
        echo "Errors during build"
        rm -rf out/
        exit 1
    fi

    rootfs_sz_real=$(du -h /tmp/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.raw | cut -f1)

    # make sure that there are the same for all images, in case we build more than 1 image
    if [ -f MD5SUM ]; then
        md5sum -c MD5SUM
    else
        md5sum out/{vmlinuz-*,config-*,$(basename ${DTBS})} > MD5SUM
    fi

    img2simg /tmp/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.raw out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.img
    sudo rm -f /tmp/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.img.raw

    # Compress image(s)
    pigz -9 out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.img

    # dpkg -l output
    mv out/packages.txt out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.packages

    # record changes since last build, if available
    if wget -q ${PUBLISH_SERVER}$(dirname ${PUB_DEST})/latest/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-*.packages -O last-build.packages; then
        echo -e "=== Packages changes for ${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}\n" >> out/build-changes.txt
        python debpkgdiff.py last-build.packages out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.packages >> out/build-changes.txt
        echo >> out/build-changes.txt
    else
        echo "latest build published does not have packages list, skipping diff report"
    fi

    # record list of installed packages in git
    cp out/${VENDOR}-${OS_FLAVOUR}-${rootfs}-${PLATFORM_NAME}-${BUILD_NUMBER}.packages lt-ci/${VENDOR}-${OS_FLAVOUR}-${rootfs}.packages

    cat >> out/HEADER.textile << EOF
* Linaro Debian ${rootfs}: size: ${rootfs_sz_real}
EOF
done

# Record info about kernel, there can be multiple .packages files, but we have already checked that kernel version is the same. so pick one.
kernel_binpkg=$(grep -h linux-image out/${VENDOR}-${OS_FLAVOUR}-*-${PLATFORM_NAME}-${BUILD_NUMBER}.packages | sed 's/\s\s*/ /g' | cut -d ' ' -f2 | uniq)
kernel_pkgver=$(grep -h linux-image out/${VENDOR}-${OS_FLAVOUR}-*-${PLATFORM_NAME}-${BUILD_NUMBER}.packages | sed 's/\s\s*/ /g' | cut -d ' ' -f3 | uniq)

# record kernel config changes since last build, if available
if wget -q ${PUBLISH_SERVER}$(dirname ${PUB_DEST})/latest/config-* -O last-build.config; then
    echo -e "=== Changes for kernel config\n" >> out/build-changes.txt
    diff -su last-build.config out/config-* >> out/build-changes.txt || true
    echo >> out/build-changes.txt
else
    echo "latest build published does not have kernel config, skipping diff report"
fi

# record kernel config changes in git
cp out/config-* lt-ci/config

# the space after pre.. tag is on purpose
if [ -f out/build-changes.txt ]; then
    cat > out/README.textile << EOF

h4. Build changes

pre.. 
EOF
    cat out/build-changes.txt >> out/README.textile
else
    cat > out/README.textile << EOF

h4. No build changes
EOF
fi

cat >> out/HEADER.textile << EOF
* Kernel package name: ${kernel_binpkg}
* Kernel package version: ${kernel_pkgver}
EOF

# Commit build changes in lt-ci
cd lt-ci
git add -A
git commit --allow-empty -m "Import build ${BUILD_NUMBER}"
git push origin debian/${PLATFORM_NAME}
cd ..

# Create boot image
cat out/vmlinuz-* out/$(basename ${DTBS}) > Image.gz+dtb
mkbootimg \
    --kernel Image.gz+dtb \
    --ramdisk out/initrd.img-* \
    --output out/boot-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${BUILD_NUMBER}.img \
    --pagesize "${BOOTIMG_PAGESIZE}" \
    --base "${BOOTIMG_BASE}" \
    --kernel_offset "${BOOTIMG_KERNEL_OFFSET}" \
    --ramdisk_offset "${BOOTIMG_RAMDISK_OFFSET}" \
    --tags_offset "${BOOTIMG_TAGS_OFFSET}" \
    --cmdline "root=/dev/disk/by-partlabel/${ROOTFS_PARTLABEL} rw rootwait console=tty0 console=${SERIAL_CONSOLE},115200n8"
pigz -9 out/boot-${VENDOR}-${OS_FLAVOUR}-${PLATFORM_NAME}-${BUILD_NUMBER}.img
