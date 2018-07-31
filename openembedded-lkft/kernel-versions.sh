#!/bin/bash

# Variables needed here:
#  KERNEL_REPO         A clonable Git repository.
#  KERNEL_BRANCH       The branch to checkout.
#  KERNEL_COMMIT       (Optional) A commit to go to. This is
#                      assumed to be part of the KERNE_BRANCH.
#
# This will create a file named ${WORKSPACE}/linux_versions
# that can then be injected into the environment. The contents
# will be:
#  KERNEL_DESCRIBE     The output of `git describe --always`.
#  KERNEL_SRCREV       The actual commit id that is the result
#                      of the checkout or reset.
#  MAKE_KERNELVERSION  The output of running `make
#                      kernelversion` in the Linux tree.

set -xe

git clone --reference-if-able "${HOME}/srv/linux.git" -o origin "${KERNEL_REPO}" "${WORKSPACE}/linux"
cd "${WORKSPACE}/linux"
git checkout "origin/${KERNEL_BRANCH}"
if [ "${KERNEL_COMMIT}" ]; then
  git reset --hard "${KERNEL_COMMIT}"
fi

GIT_COMMIT="$(git rev-parse HEAD)"

echo "KERNEL_DESCRIBE=$(git describe --always)" >> "${WORKSPACE}/linux_versions"
echo "KERNEL_SRCREV=${GIT_COMMIT}" >> "${WORKSPACE}/linux_versions"
echo "MAKE_KERNELVERSION=$(make kernelversion)" >> "${WORKSPACE}/linux_versions"
cat "${WORKSPACE}/linux_versions"
