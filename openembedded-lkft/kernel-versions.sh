#!/bin/bash

# Variables needed here:
#  KERNEL_REPO         A clonable Git repository.
#  KERNEL_REV          The branch or commit ID to checkout.
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
git remote add torvalds https://github.com/torvalds/linux.git
git remote add linux-stable https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
git remote add linux-stable-rc https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
git fetch --multiple torvalds linux-stable linux-stable-rc
git checkout "${KERNEL_REV}"
GIT_COMMIT="$(git rev-parse HEAD)"

MAKE_KERNELVERSION="$(make kernelversion)"
kernel_major="$(echo ${MAKE_KERNELVERSION} | cut -d\. -f1)"
kernel_minor="$(echo ${MAKE_KERNELVERSION} | cut -d\. -f2)"
if echo "${MAKE_KERNELVERSION}" | grep -q "rc"; then
  kernel_minor=$((kernel_minor - 1))
fi
echo "KERNEL_DESCRIBE=$(git describe --always)" >> "${WORKSPACE}/linux_versions"
echo "KERNEL_SRCREV=${GIT_COMMIT}" >> "${WORKSPACE}/linux_versions"
echo "MAKE_KERNELVERSION=${MAKE_KERNELVERSION}" >> "${WORKSPACE}/linux_versions"
echo "KERNEL_VERSION=${kernel_major}.${kernel_minor}" >> "${WORKSPACE}/linux_versions"
echo "KERNEL_BRANCH=linux-${kernel_major}.${kernel_minor}.y" >>"${WORKSPACE}/linux_versions"
cat "${WORKSPACE}/linux_versions"
