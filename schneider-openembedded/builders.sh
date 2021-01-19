#!/bin/bash
set -e

# workaround EDK2 is confused by the long path used during the build
# and truncate files name expected by VfrCompile
sudo mkdir -p /srv/oe
sudo chown buildslave:buildslave /srv/oe
cd /srv/oe

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    echo "Running cleanup_exit..."
}

replace_dmverity_var()
{
	local variable
	local localconf
	local newvalue

	variable="DM_VERITY_IMAGE_NAME"
	localconf="conf/local.conf"
	newvalue="${1}"

	sed -i 's/'${variable}' ?=.*/'${variable}' ?= "'${newvalue}'"/' ${localconf}
	grep ${variable} ${localconf} || true
}

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="python-pip android-tools-fsutils chrpath cpio diffstat gawk libmagickwand-dev libmath-prime-util-perl libsdl1.2-dev libssl-dev python-requests texinfo vim-tiny whiptail"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

# Install ruamel.yaml
pip install --user --force-reinstall ruamel.yaml

set -ex

#DEL mkdir -p ${HOME}/bin
#DEL curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
#DEL chmod a+x ${HOME}/bin/repo
#DEL export PATH=${HOME}/bin:${PATH}

# initialize repo if not done already
if [ ! -e ".repo/manifest.xml" ]; then
   #DEL repo init -u ${MANIFEST_URL} -b ${MANIFEST_BRANCH_PREFIX}${MANIFEST_BRANCH}

   # link to shared downloads on persistent disk
   # our builds config is expecting downloads and sstate-cache, here.
   # DL_DIR = "${OEROOT}/sources/downloads"
   # SSTATE_DIR = "${OEROOT}/build/sstate-cache"
   sstatecache=${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH}
   if [[ "${IMAGES}" == *clean* ]]; then
     rm -rf ${sstatecache}
   fi
   mkdir -p ${HOME}/srv/oe/downloads ${sstatecache}
   #DEL mkdir -p build
   #DEL ln -s ${HOME}/srv/oe/downloads
   #DEL ln -s ${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH} sstate-cache
fi


#DEL if [ "${ghprbPullId}" ]; then
#DEL     echo "Applying Github pull-request #${ghprbPullId} from ${ghprbGhRepository}"
#DEL     sed -i -e "s|name=\"${ghprbGhRepository}\"|name=\"${ghprbGhRepository}\" revision=\"refs/pull/${ghprbPullId}/head\"|" .repo/manifest.xml
#DEL fi

#DEL repo sync
#DEL cp .repo/manifest.xml source-manifest.xml
#DEL repo manifest -r -o pinned-manifest.xml
#DEL MANIFEST_COMMIT=$(cd .repo/manifests && git rev-parse --short HEAD)

#DEL  record changes since last build, if available
#DEL if wget -q ${BASE_URL}${PUB_DEST/\/${BUILD_NUMBER}\//\/latest\/}/pinned-manifest.xml -O pinned-manifest-latest.xml; then
#DEL     repo diffmanifests ${PWD}/pinned-manifest-latest.xml ${PWD}/pinned-manifest.xml > manifest-changes.txt
#DEL else
#DEL     echo "latest build published does not have pinned-manifest.xml, skipping diff report"
#DEL fi

#DEL if [ -n "$GERRIT_PROJECT" ] && [ $GERRIT_EVENT_TYPE == "patchset-created" ]; then
#DEL     GERRIT_URL="http://${GERRIT_HOST}/${GERRIT_PROJECT}"
#DEL     cd `grep -rni $GERRIT_PROJECT\" .repo/manifest.xml | grep -Po 'path="\K[^"]*'`
#DEL     if git pull ${GERRIT_URL} ${GERRIT_REFSPEC} | grep -q "Automatic merge failed"; then
#DEL         git reset --hard
#DEL         echo "Error: *** Error patch merge failed"
#DEL         exit 1
#DEL     fi
#DEL     cd -
#DEL fi

git clone ${DISTRO_URL_BASE}/${DISTRO_DIR} -b ${MANIFEST_BRANCH}
cd ${DISTRO_DIR}
git log -1
git submodule init
git submodule update

# the setup-environment will create auto.conf and site.conf
# make sure we get rid of old config.
# let's remove the previous TMPDIR as well.
# we want to preserve build/buildhistory though.
#DEL rm -rf conf build/conf build/tmp/

# Accept EULA if/when needed
#DEL export EULA_dragonboard410c=1
#DEL export EULA_stih410b2260=1
#DEL source setup-environment build

# Set the machine to the value expected by the Yocto environment
# We set it back again later
machine_orig=${MACHINE}
case "${MACHINE}" in
  *rzn1*)
    MACHINE=rzn1-snarc
    ;;
  *soca9*)
    MACHINE=snarc-soca9
    ;;
esac

# SUBMODULES is set to:
#	none		no update
#	''		update default set in setup-env...
#	all		tell setup-env... to update all submodules
#	'<something>'	pass the variable to submodule update
if [[ ${MANIFEST_BRANCH} == linaro-* ]];
then
	if [[ "${SUBMODULES}" != "none" ]]; then
	  ./setup-environment -s build-${machine_orig}/
	fi
fi

source ./setup-environment build-${machine_orig}/

ln -s ${HOME}/srv/oe/downloads
ln -s ${sstatecache} sstate-cache

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

# Make sure we don't use rm_work in CI slaves since they are non persistent build nodes
cat << EOF >> conf/auto.conf
INHERIT_remove = "rm_work"
EOF

# allow the top level job to append to auto.conf
if [ -f ${WORKSPACE}/auto.conf ]; then
    cat ${WORKSPACE}/auto.conf >> conf/auto.conf
fi

# add useful debug info
cat conf/auto.conf

[ "${DISTRO}" = "rpb" ] && IMAGES+=" ${IMAGES_RPB}"
[ "${DISTRO}" = "rpb-wayland" ] && IMAGES+=" ${IMAGES_RPB_WAYLAND}"

# These machines only build the basic rpb-console-image
case "${MACHINE}" in
  am57xx-evm|intel-core2-32|intel-corei7-64)
     IMAGES="rpb-console-image"
     ;;
  *rzn1*)
    clean_packages="\
        openssl-native \
        optee-os \
    "
    build_packages="${clean_packages}"
    ;;
  *soca9*)
    clean_packages="\
        base-files \
        u-boot-socfpga \
        linux-socfpga \
        "
    build_packages="${clean_packages}"
    IMAGES="$(echo $IMAGES | sed -e 's/dip-image-edge//')"
    ;;
esac

postfile=$(mktemp /tmp/postfile.XXXXX.conf)
echo KERNEL_VERSION_PATCHLEVEL = \"${KERNEL_VERSION_PATCHLEVEL}\" > ${postfile}
echo PREFERRED_VERSION_linux-rzn1 = \"${KERNEL_VERSION_PATCHLEVEL}.%\" >> ${postfile}
echo PREFERRED_VERSION_linux-socfpga = \"${KERNEL_VERSION_PATCHLEVEL}.%\" >> ${postfile}
cat ${postfile}
bbopt="-R ${postfile}"

if [ "${clean_packages}" != "" ]; then
    bitbake ${bbopt} -c cleansstate ${clean_packages}
    bitbake ${bbopt} ${build_packages}
fi

# Build all ${IMAGES} apart from dip-image-edge
dipimg="dip-image"
devimg="dip-image-dev"
edgeimg="dip-image-edge"
hasdipimg=$(echo ${IMAGES} | sed -e 's/'${devimg}'//g' -e 's/'${edgeimg}'//g')

DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE="| cut -d'=' -f2 | tr -d '"')

if [[ "${hasdipimg}" == *"${dipimg}"* ]]; then
	replace_dmverity_var "${dipimg}"

	grep -c ^processor /proc/cpuinfo
	grep ^cpu\\scores /proc/cpuinfo | uniq |  awk '{print $4}'

	time bitbake ${bbopt} dip-image dip-sdk

	case "${MACHINE}" in
		*rzn1*)
			cat tmp/deploy/images/rzn1-snarc/dip-image.squashfs-lzo.verity.env || true
			time bitbake ${bbopt} fsbl optee-os u-boot-rzn1
			time bitbake ${bbopt} -c do_install       fsbl        || true
			time bitbake ${bbopt} -c do_fit_optee_os  optee-os    || true
			time bitbake ${bbopt} -c do_fit_rzn1d     u-boot-rzn1 || true
			;;
	esac

	# Generate pn-buildlist containing names of recipes, for CVE check below
	time bitbake ${bbopt} dip-image -g

	DEPLOY_DIR_SDK=$(bitbake -e | grep "^DEPLOY_DIR="| cut -d'=' -f2 | tr -d '"')/sdk
	cp -aR ${DEPLOY_DIR_SDK} ${DEPLOY_DIR_IMAGE}

	ls -al ${DEPLOY_DIR_IMAGE} || true
	ls -al ${DEPLOY_DIR_IMAGE}/optee || true
fi

if [[ "${IMAGES}" == *"${devimg}"* ]]; then
	replace_dmverity_var ""
	time bitbake ${bbopt} ${devimg}

	ls -al ${DEPLOY_DIR_IMAGE} || true
	ls -al ${DEPLOY_DIR_IMAGE}/optee || true

	# Copy license and manifest information into the deploy dir
	cp -aR ./tmp/deploy/licenses/dip-image-dev-*/*.manifest ${DEPLOY_DIR_IMAGE}
fi

# now build dip-image-edge if it was in ${IMAGES}
if [[ "${IMAGES}" == *"${edgeimg}"* ]]; then
	rm -rf ${DEPLOY_DIR_IMAGE}-pre || true

	# stash the deployed images for later
	find ${DEPLOY_DIR_IMAGE} -type l -delete
	mv ${DEPLOY_DIR_IMAGE} ${DEPLOY_DIR_IMAGE}-pre

	replace_dmverity_var "${edgeimg}"

	# replace layer meta-dip-dev with meta-edge and then build dip-image-edge
	mkdir -p ${DEPLOY_DIR_IMAGE}
	sed -i conf/bblayers.conf -e 's#meta-dip-dev#meta-edge#'
	time bitbake ${bbopt} ${edgeimg}

	# Overwrite pn-buildlist, for CVE check below
	time bitbake ${bbopt} ${edgeimg} -g

	# restore layer meta-dip-dev
	sed -i conf/bblayers.conf -e 's#meta-edge#meta-dip-dev#'

	# The kernel will exist in both ${DEPLOY_DIR_IMAGE} and ${DEPLOY_DIR_IMAGE}-pre
	# The files will be binary identical, but have different date stamps
	# So remove the newer ones
	rm -f ${DEPLOY_DIR_IMAGE}/zImage-*.bin
	rm -f ${DEPLOY_DIR_IMAGE}/*.dtb
	rm -f ${DEPLOY_DIR_IMAGE}/modules-*.tgz

	# Move the saved images back to the deploy dir
	cp -aR ${DEPLOY_DIR_IMAGE}-pre/* ${DEPLOY_DIR_IMAGE}
	ls -al ${DEPLOY_DIR_IMAGE}
	ls -al ${DEPLOY_DIR_IMAGE}/optee || true
fi

# Prepare files to publish
rm -f ${DEPLOY_DIR_IMAGE}/*.txt
find ${DEPLOY_DIR_IMAGE} -type l -delete
#DEL mv /srv/oe/{source,pinned}-manifest.xml ${DEPLOY_DIR_IMAGE}
#DEL cat ${DEPLOY_DIR_IMAGE}/pinned-manifest.xml

### Begin CVE check

# Combine CVE reports for the recipes used in dip-image task.
CVE_CHECK_DIR=$(bitbake -e | grep "^CVE_CHECK_DIR="| cut -d'=' -f2 | tr -d '"')
if [ -e pn-buildlist ] && [ -e "${CVE_CHECK_DIR}" ]; then
	sort pn-buildlist | while read r ; do
		cat ${CVE_CHECK_DIR}/${r} 2>/dev/null || true
	done >cve-${MACHINE}.new

	# Generate CVE listing with a fixed filename, so it can be retrieved
	# from snapshots.linaro.org by subsequent builds using a known URL.
	cp cve-${MACHINE}.new ${DEPLOY_DIR_IMAGE}/dip-image-${MACHINE}.rootfs.cve

	# Fetch previous CVE report
	LATEST_DEST=$(echo $PUB_DEST | sed -e "s#/$BUILD_NUMBER/#/latest/#")
	rm -f cve-${MACHINE}.old
	wget -nv -O cve-${MACHINE}.old ${BASE_URL}/${LATEST_DEST}/dip-image-${MACHINE}.rootfs.cve || true

	# Download may fail (404 error), or might not contain the report (auth error)
	if ! grep -q "PACKAGE NAME" cve-${MACHINE}.old 2>/dev/null; then
		# Use current CVE list, to avoid diff-against-nothing
		cp cve-${MACHINE}.new cve-${MACHINE}.old
		# Append a fake entry that will appear in the diff
		cat <<-EOF >>cve-${MACHINE}.old
		PACKAGE NAME: failed-to-download-previous-CVEs
		PACKAGE VERSION: 0.0
		CVE: CVE-xxxx-yyyy
		CVE STATUS: Unpatched
		CVE SUMMARY: Unable to download CVE results for previous build. Comparison disabled.
		CVSS v2 BASE SCORE: 0.0
		CVSS v3 BASE SCORE: 0.0
		VECTOR: LOCAL
		MORE INFORMATION: none
		EOF
	fi

	if [ -e cve-${MACHINE}.old ]; then
		# Do diffs between old and current CVE report.
		wget -nv -O diff-cve https://git.linaro.org/ci/job/configs.git/plain/schneider-openembedded/diff-cve
		gawk -f diff-cve cve-${MACHINE}.old cve-${MACHINE}.new | tee ${WORKSPACE}/cve-${MACHINE}.txt

		# Same thing, but against arbitrary (but fixed) baseline
		case "${MACHINE}" in
			*rzn1*)
			wget -nv -O cve-${MACHINE}.base https://releases.linaro.org/members/schneider/openembedded/2020.09-dunfell/rzn1d-5.4/dip-image-rzn1-snarc.rootfs.cve
			;;
			*soca9*)
			wget -nv -O cve-${MACHINE}.base https://releases.linaro.org/members/schneider/openembedded/2020.09-dunfell/soca9-5.4/dip-image-snarc-soca9.rootfs.cve
			;;
		esac
		gawk -f diff-cve cve-${MACHINE}.base cve-${MACHINE}.new > ${WORKSPACE}/base-cve-${MACHINE}.txt
	else
		echo "CVE check skipped because no previous build was found"
	fi
	### End CVE check
fi

# FIXME: IMAGE_FSTYPES_remove doesn't work
rm -f ${DEPLOY_DIR_IMAGE}/*.rootfs.ext4 \
      ${DEPLOY_DIR_IMAGE}/*.rootfs.iso \
      ${DEPLOY_DIR_IMAGE}/*.iso \
      ${DEPLOY_DIR_IMAGE}/*.jffs* \
      ${DEPLOY_DIR_IMAGE}/*.cpio.gz \
      ${DEPLOY_DIR_IMAGE}/*.stimg

# FIXME: Sparse images here, until it gets done by OE
case "${MACHINE}" in
  *rzn1*)
    pushd ${DEPLOY_DIR_IMAGE}
    rm -f uImage*
    popd
    ;;
  *soca9*)
    # re-create the SoCA9 DTB with a shorter filename
    pushd ${DEPLOY_DIR_IMAGE}
    mv zImage-*soca9*_bestla_512m*.dtb zImage-soca9_qspi_micronN25Q_bestla_512m.dtb || true
    mv zImage-*soca9*.dtb zImage-soca9_qspi_micronN25Q_bestla_512m.dtb || true
    rm -f *[12]G*.dtb || true
    rm -f *freja*.dtb || true
    rm -f *socfpga_cyclone5_socdk*.dtb || true
    popd
    ;;
  juno|stih410-b2260|orangepi-i96)
    ;;
  *)
    for rootfs in $(find ${DEPLOY_DIR_IMAGE} -type f -name *.rootfs.ext4.gz); do
      gunzip -k ${rootfs}
      sudo ext2simg -v ${rootfs%.gz} ${rootfs%.ext4.gz}.img
      rm -f ${rootfs%.gz}
      gzip -9 ${rootfs%.ext4.gz}.img
    done
    ;;
esac

ls -al ${DEPLOY_DIR_IMAGE}/*

# Create MD5SUMS file
find ${DEPLOY_DIR_IMAGE} -type f | xargs md5sum > MD5SUMS.txt
sed -i "s|${DEPLOY_DIR_IMAGE}/||" MD5SUMS.txt
mv MD5SUMS.txt ${DEPLOY_DIR_IMAGE}

# Build information
cat > ${DEPLOY_DIR_IMAGE}/HEADER.textile << EOF

h4. Reference Platform Build - CE OpenEmbedded

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Manifest URL: "${MANIFEST_URL}":${MANIFEST_URL}
* Manifest branch: ${MANIFEST_BRANCH_PREFIX}${MANIFEST_BRANCH}
* Manifest commit: "${MANIFEST_COMMIT}":${MANIFEST_URL/.git/\/commit}/${MANIFEST_COMMIT}
EOF

if [ -e "/srv/oe/manifest-changes.txt" ]; then
  # the space after pre.. tag is on purpose
  cat > ${DEPLOY_DIR_IMAGE}/README.textile << EOF

h4. Manifest changes

pre.. 
EOF
  cat /srv/oe/manifest-changes.txt >> ${DEPLOY_DIR_IMAGE}/README.textile
  mv /srv/oe/manifest-changes.txt ${DEPLOY_DIR_IMAGE}
fi

# Identify snapshots as public
touch ${DEPLOY_DIR_IMAGE}/OPEN-EULA.txt

# Need different files for each machine
ROOTFS_EXT4_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-test-*rzn1*-*-${BUILD_NUMBER}.rootfs.ext4.gz" | xargs -r basename)
ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-test-*rzn1*-*-${BUILD_NUMBER}.rootfs.tar.xz" | xargs -r basename)
ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-test-*rzn1*-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
ROOTFS_DESKTOP_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-desktop-image-test-*rzn1*-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "zImage-*-*rzn1*-*-${BUILD_NUMBER}.bin" | xargs -r basename)
case "${MACHINE}" in
  am57xx-evm)
    # LAVA image is too big for am57xx-evm
    ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
    # FIXME: several dtb files case
    ;;
  intel-core2-32|intel-corei7-64)
    # No LAVA testing on intel-core* machines
    ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.tar.xz" | xargs -r basename)
    ;;
  juno)
    # FIXME: several dtb files case
    ;;
  *rzn1*)
    ROOTFS_TAR_BZ2=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-rzn1*-*-${BUILD_NUMBER}.rootfs.tar.bz2" | xargs -r basename)
    ROOTFS_DEV_TAR_BZ2=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-dev-rzn1*-*-${BUILD_NUMBER}.rootfs.tar.bz2" | xargs -r basename)
    ROOTFS_EDGE_TAR_BZ2=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-edge-rzn1*-*-${BUILD_NUMBER}.rootfs.tar.bz2" | xargs -r basename)
    WIC_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-rzn1*-${BUILD_NUMBER}.rootfs.wic.bz2" | xargs -r basename)
    WIC_BMAP=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-rzn1*-${BUILD_NUMBER}.rootfs.wic.bmap" | xargs -r basename)
    WIC_DEV_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-dev-rzn1*-${BUILD_NUMBER}.rootfs.wic.bz2" | xargs -r basename)
    WIC_DEV_BMAP=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-dev-rzn1*-${BUILD_NUMBER}.rootfs.wic.bmap" | xargs -r basename)
    WIC_EDGE_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-edge-rzn1*-${BUILD_NUMBER}.rootfs.wic.bz2" | xargs -r basename)
    WIC_EDGE_BMAP=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-edge-rzn1*-${BUILD_NUMBER}.rootfs.wic.bmap" | xargs -r basename)
    UBI_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-rzn1-snarc-*-${BUILD_NUMBER}.rootfs.ubi" | xargs -r basename)
    UBI_DEV_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-dev-rzn1-snarc-*-${BUILD_NUMBER}.rootfs.ubi" | xargs -r basename)
    UBI_EDGE_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-edge-rzn1-snarc-*-${BUILD_NUMBER}.rootfs.ubi" | xargs -r basename)
    DTB_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "*rzn1*bestla*.dtb" | xargs -r basename)
    KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "zImage--*rzn1*.bin" | xargs -r basename)
    KERNEL_FIT_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "fitImage*.itb" | xargs -r basename)
    UBOOT_FIT_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "ubootfitImage*.itb" | xargs -r basename)
    OPTEE_FIT_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "optee-os*.itb" | xargs -r basename)
    FSBL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rzn1d-snarc-fsbl-fip*.spkg" | xargs -r basename)
    ;;
  *soca9*)
    ROOTFS_TAR_BZ2=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-snarc-soca9-*-${BUILD_NUMBER}.rootfs.tar.bz2" | xargs -r basename)
    ROOTFS_DEV_TAR_BZ2=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-dev-snarc-soca9*-${BUILD_NUMBER}.rootfs.tar.bz2" | xargs -r basename)
    WIC_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-snarc-soca9-*-${BUILD_NUMBER}.rootfs.wic.bz2" | xargs -r basename)
    WIC_BMAP=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-snarc-soca9-*-${BUILD_NUMBER}.rootfs.wic.bmap" | xargs -r basename)
    WIC_DEV_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-dev-snarc-soca9-*-${BUILD_NUMBER}.rootfs.wic.bz2" | xargs -r basename)
    WIC_DEV_BMAP=$(find ${DEPLOY_DIR_IMAGE} -type f -name "dip-image-dev-snarc-soca9-*-${BUILD_NUMBER}.rootfs.wic.bmap" | xargs -r basename)
    DTB_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "*soca9*_qspi_micronN25Q_bestla_512m.dtb" | xargs -r basename)
    KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "zImage--*soca9*.bin" | xargs -r basename)
    ;;
  *)
    DTB_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "*-${MACHINE}-*-${BUILD_NUMBER}.dtb" | xargs -r basename)
    ;;
esac

# Set MACHINE back to the origin value
MACHINE=${machine_orig}

# Note: the main job script allows to override the default value for
#       BASE_URL and PUB_DEST, typically used for OE RPB builds
cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
MANIFEST_COMMIT=${BUILD_NUMBER}
ROOTFS_BUILD_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_EXT4_IMG}
ROOTFS_SPARSE_BUILD_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_IMG}
ROOTFS_DESKTOP_SPARSE_BUILD_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_DESKTOP_IMG}
SYSTEM_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_EXT4_IMG}
OPTEE_ITB_URL=${BASE_URL}${PUB_DEST}/optee/${OPTEE_FIT_IMG}
FSBL_URL=${BASE_URL}${PUB_DEST}/${FSBL_IMG}
UBOOT_ITB_URL=${BASE_URL}${PUB_DEST}/${UBOOT_FIT_IMG}
KERNEL_FIT_URL=${BASE_URL}${PUB_DEST}/${KERNEL_FIT_IMG}
KERNEL_ZIMAGE_URL=${BASE_URL}${PUB_DEST}/${KERNEL_IMG}
WIC_IMAGE_URL=${BASE_URL}${PUB_DEST}/${WIC_IMG}
WIC_BMAP_URL=${BASE_URL}${PUB_DEST}/${WIC_BMAP}
WIC_DEV_IMAGE_URL=${BASE_URL}${PUB_DEST}/${WIC_DEV_IMG}
WIC_DEV_BMAP_URL=${BASE_URL}${PUB_DEST}/${WIC_DEV_BMAP}
WIC_EDGE_IMAGE_URL=${BASE_URL}${PUB_DEST}/${WIC_EDGE_IMG}
WIC_EDGE_BMAP_URL=${BASE_URL}${PUB_DEST}/${WIC_EDGE_BMAP}
UBI_IMAGE_URL=${BASE_URL}${PUB_DEST}/${UBI_IMG}
UBI_DEV_IMAGE_URL=${BASE_URL}${PUB_DEST}/${UBI_DEV_IMG}
UBI_EDGE_IMAGE_URL=${BASE_URL}${PUB_DEST}/${UBI_EDGE_IMG}
DTB_URL=${BASE_URL}${PUB_DEST}/${DTB_IMG}
NFSROOTFS_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_TAR_BZ2}
NFSROOTFS_DEV_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_DEV_TAR_BZ2}
NFSROOTFS_EDGE_URL=${BASE_URL}${PUB_DEST}/${ROOTFS_EDGE_TAR_BZ2}
RECOVERY_IMAGE_URL=${BASE_URL}${PUB_DEST}/juno-oe-uboot.zip
LXC_ROOTFS_IMG=$(basename ${ROOTFS_IMG} .gz)
DEVICE_TYPE=${MACHINE}
EOF
