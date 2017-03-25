# Build Android
repo init -u ${ANDROID_MANIFEST_URL} -b ${MANIFEST_BRANCH}
repo sync -j"$(nproc)" -c

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

mkdir pub
wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/generic/build-info/public-template.txt -O pub/BUILD-INFO.txt

cp out/host/linux-x86/vts/android-vts.zip pub/

# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
PUB_SRC=${PWD}/pub
PUB_DEST=/android/${JOB_NAME}/${BUILD_NUMBER}/${LUNCH_TARGET}
PUB_EXTRA_INC=^[^/]+zip
EOF
