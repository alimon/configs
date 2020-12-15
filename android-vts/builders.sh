# Build Android vts
export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8

# change to the build directory to repo sync and build
cd build
repo init -u ${ANDROID_MANIFEST_URL} -b ${MANIFEST_BRANCH} \
        --repo-branch=master --no-repo-verify
repo sync -j"$(nproc)" -c
rm -rf out/

mkdir -p pub
repo manifest -r -o pub/pinned-manifest.xml

if [ -n "$PATCHSETS" ]; then
    rm -rf android-patchsets
    git clone --depth=1 https://android-git.linaro.org/git/android-patchsets.git
    for i in $PATCHSETS; do
        sh ./android-patchsets/$i
    done
fi

source build/envsetup.sh
lunch ${LUNCH_TARGET}
make -j"$(nproc)" vts

wget -q https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/generic/build-info/public-template.txt -O pub/BUILD-INFO.txt

cp out/host/linux-x86/vts/android-vts.zip pub/

# Delete sources after build to save space
rm -rf art/ dalvik/ kernel/ bionic/ developers/ libcore/ sdk/ bootable/ development/ libnativehelper/ system/ build/ device/ test/ build-info/ docs/ packages/ toolchain/ .ccache/ external/ pdk/ tools/ compatibility/ frameworks/ platform_testing/ vendor/ cts/ hardware/ prebuilts/ linaro* out/

# need to convert '_' to '-'
# otherwise, aosp_arm64-userdebug will be translated to '~aosp/arm64-userdebug'
# when upload to snapshot.linaro.org via linaro-cp.py
# like reported here:
# https://ci.linaro.org/job/android-cts/20/console
lunch_target_str=$(echo ${LUNCH_TARGET}|tr '_' '-')
# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
PUB_SRC=${PWD}/pub
PUB_DEST=/android/${JOB_NAME}/${lunch_target_str}/${BUILD_NUMBER}/${MANIFEST_BRANCH}
PUB_EXTRA_INC=^[^/]+zip
EOF
