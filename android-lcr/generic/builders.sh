# Build Android
export JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8

repo init -u ${ANDROID_MANIFEST_URL} -b ${MANIFEST_BRANCH}
repo sync -j"$(nproc)" -c

if [ -n "${BLOBS_URL}" ]; then
IFS='#'; for url in ${BLOBS_URL}; do
  wget -q ${url}
  tar -xvf $(basename ${url})
  yes "I ACCEPT"|sh *.sh
  rm *.sh
  rm $(basename ${url})
done
fi
unset IFS

if [ -n "$PATCHSETS" ]; then
    rm -rf android-patchsets
    git clone --depth=1 https://android-git.linaro.org/git/android-patchsets.git
    for i in $PATCHSETS; do
        sh ./android-patchsets/$i
    done
fi
source build/envsetup.sh
lunch ${LUNCH_TARGET}
make -j"$(nproc)"

template="private-template.txt"
if [ "${BUILD_TYPE}" = "public" ]; then
  template="public-template.txt"
fi
wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/generic/build-info/${template} -O ${ANDROID_PRODUCT_OUT}/BUILD-INFO.txt

# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
PUB_SRC=$(readlink -f ${ANDROID_PRODUCT_OUT})
PUB_DEST=/android/${JOB_NAME}/${BUILD_NUMBER}/${LUNCH_TARGET}
EOF

# delete workspace after buildig files
rm -rf Android.bp bootstrap.bash compatibility developers external kernel prebuilts  toolchain art build config.txt development frameworks libcore packages sdk tools bionic build-configs cts device hardware libnativehelper pdk system bootable build-tools dalvik docs jenkins-tools Makefile platform_testing
