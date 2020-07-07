#!/bin/bash

set -ex

PUB_SRC=${PUB_SRC:-${HOME}/srv/${JOB_NAME}/build/out}
PUB_DEST=${PUB_DEST:-/android/${JOB_NAME}/${BUILD_NUMBER}}

# default to link latest
# and set to not link latest when specified explicitly
OPT_LINK_LATEST="--link-latest"
if [ -n "${LINK_LATEST}" ] && [ "X${LINK_LATEST}" = "Xfalse" ]; then
    OPT_LINK_LATEST=""
fi
# Publish
test -d ${HOME}/bin || mkdir ${HOME}/bin
wget -q https://git.linaro.org/ci/publishing-api.git/blob_plain/HEAD:/linaro-cp.py -O ${HOME}/bin/linaro-cp.py
time python3 ${HOME}/bin/linaro-cp.py \
  --manifest \
  --no-build-info \
  ${OPT_LINK_LATEST} \
  --split-job-owner \
  --server ${PUBLISH_SERVER} \
  ${PUB_SRC} \
  ${PUB_DEST} \
  --include "^[^/]+[._](img[^/]*|tar[^/]*|bin[^/]*|xml|sh|config|json)$" \
  --include "^[BHi][^/]+txt$" \
  --include "^(MANIFEST|MD5SUMS|changelog.txt)$" \
  $([ -z "${PUB_EXTRA_INC}" ] || echo "--include ${PUB_EXTRA_INC}")
