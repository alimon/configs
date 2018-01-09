# Build Android
export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8

repo init -u ${ANDROID_MANIFEST_URL} -b ${MANIFEST_BRANCH}
repo sync -j"$(nproc)" -c

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
make -j"$(nproc)" cts

wget -q https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/generic/build-info/public-template.txt -O pub/BUILD-INFO.txt

cp out/host/linux-x86/cts/android-cts.zip pub/

rm -rf art/ dalvik/ kernel/ bionic/ developers/ libcore/ sdk/ bootable/ development/ libnativehelper/ system/ build/ device/ test/ build-info/ docs/ packages/ toolchain/ .ccache/ external/ pdk/ tools/ compatibility/ frameworks/ platform_testing/ vendor/ cts/ hardware/ prebuilts/ linaro*

# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
PUB_SRC=${PWD}/pub
PUB_DEST=/android/${JOB_NAME}/${LUNCH_TARGET}/${BUILD_NUMBER}
PUB_EXTRA_INC=^[^/]+zip
EOF
