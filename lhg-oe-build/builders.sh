#!/bin/bash

# workaround EDK2 is confused by the long path used during the build
# and truncate files name expected by VfrCompile
DIR_FOR_WORK=${HOME}/`dirname ${JOB_NAME}`
mkdir -p ${DIR_FOR_WORK}
cd ${DIR_FOR_WORK}

set -ex

mkdir -p ${HOME}/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
chmod a+x ${HOME}/bin/repo
export PATH=${HOME}/bin:${PATH}

# initialize repo
rm -rf .repo bitbake layers
repo init -u https://github.com/linaro-home/lhg-oe-manifests.git -b ${MANIFEST_BRANCH} -m default.xml
mkdir -p build

repo sync
cp .repo/manifest.xml source-manifest.xml
repo manifest -r -o pinned-manifest.xml

# the setup-environment will create local.conf, make sure we get rid
# of old config. Let's remove the previous TMPDIR as well. We want
# to preserve build/buildhistory though.
rm -rf conf build/conf build/tmp-*glibc/

# Accept EULA if/when needed
export EULA_dragonboard410c=1
source setup-environment build

bitbake ${image_type}
DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE="| cut -d'=' -f2 | tr -d '"')

# Prepare files to archive
rm -f ${DEPLOY_DIR_IMAGE}/*.txt
find ${DEPLOY_DIR_IMAGE} -type l -delete
mv ${DIR_FOR_WORK}/{source,pinned}-manifest.xml ${DEPLOY_DIR_IMAGE}

# Create MD5SUMS file
(cd ${DEPLOY_DIR_IMAGE} && md5sum * > MD5SUMS.txt)

# The archive publisher can't handle files located outside
# ${WORKSPACE} - create the link before archiving.
rm -f ${WORKSPACE}/out
ln -s ${DEPLOY_DIR_IMAGE} ${WORKSPACE}/out

# publishing is done in a separate build step, so $DEPLOY_DIR_IMAGE
# needs to be passed using "Inject environment variables"
cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
EOF
