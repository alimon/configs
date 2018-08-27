#!/bin/bash
set -ex

export PATH=$PATH://home/buildslave/bin/

sudo apt-get -q=2 update
sudo apt-get -q=2 install -y libxml2-dev zlib1g-dev libtinfo-dev git-svn gawk libxml2-utils rsync pxz python-requests ninja-build

BASEDIR="${HOME}/srv/aosp/${JOB_NAME}"
rm -rf "${BASEDIR}"
mkdir -p "${BASEDIR}"
cd "${BASEDIR}"

# Download toolchain prebuilt bootstrap tools
repo init -u https://android-git.linaro.org/git/platform/manifest.git -b linaro-upstream-llvm-toolchain
repo sync -j16 -c

# Apply needed patches, if any
for d in toolchain/patches/*; do
	[ -d "$d" ] || continue
	for i in $d/*.patch; do
		[ -e "$i" ] || continue
		p="$(realpath $i)"
		pushd "toolchain/$(basename $d)"
		echo "Applying $(basename $p)"
		patch -p1 <"$p"
		popd
	done
done

# Find the SVN revision the compiler is based on
REVISION=0
for i in clang clang-tools-extra compiler-rt libcxx libcxxabi lld llvm openmp_llvm; do
	pushd toolchain/$i
	REV=$(git log |grep git-svn-id: |head -n1 |cut -d@ -f2 |cut -d' ' -f1)
	[ "$REV" -ge "$REVISION" ] && REVISION="$REV"
	popd
done
echo "Building compiler based on clang revision $REVISION"

# And give the build script the correct version information
sed -i -e "s,^svn_revision =.*,svn_revision = 'r${REVISION}'," toolchain/llvm_android/android_version.py

# And build it...
python toolchain/llvm_android/build.py

# Recompress output to save space
mv out/*.tar.bz2 .
bunzip2 *.tar.bz2
xz -9ef *.tar

echo "Build finished"
