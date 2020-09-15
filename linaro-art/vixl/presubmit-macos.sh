#!/bin/bash -xe

vixl_repo="https://git.linaro.org/arm/vixl.git"

rm -rf vixl
git clone "${vixl_repo}" vixl
cd vixl
git fetch "${vixl_repo}" "${GERRIT_REFSPEC}" && git checkout FETCH_HEAD
./tools/test.py ${VIXL_TEST_ARGS}
