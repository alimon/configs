# Early test
if [ ! -f build-configs/${BUILD_CONFIG_FILENAME} ]; then
  echo "No config file named ${BUILD_CONFIG_FILENAME} exists"
  echo "in android-build-configs.git"
  exit 1
fi

# Clean android-patchsets and repositories in device
rm -rf build/out build/android-patchsets build/device

# Build Android
build-tools/node/build us-east-1.ec2-git-mirror.linaro.org "${CONFIG}"
cp -a /home/buildslave/srv/${BUILD_DIR}/build/out/*.json /home/buildslave/srv/${BUILD_DIR}/build/out/*.xml ${WORKSPACE}/

cd build/out
for image in "boot.img" "system.img" "userdata.img"  "cache.img"; do
  if [ -f ${image} ]; then
    echo "Compressing ${image}"
    xz ${image}
  fi
done
cd -

rm -rf build/out/BUILD-INFO.txt
wget https://git.linaro.org/ci/job/configs.git/plain/android-lcr/generic/build-info/public-template.txt -O build/out/BUILD-INFO.txt

cat << EOF > ${WORKSPACE}/publish_parameters
PUB_DEST=96boards/dragonboard410c/linaro/aosp-master/${BUILD_NUMBER}
PUB_SRC=${PWD}/build/out
PUB_EXTRA_INC=^[^/]+zip
EOF

# Delete sources after build to save space
cd build
rm -rf art/ dalvik/ kernel/ bionic/ developers/ libcore/ sdk/ bootable/ development/ libnativehelper/ system/ build/ device/ test/ build-info/ docs/ packages/ toolchain/ .ccache/ external/ pdk/ tools/ compatibility/ frameworks/ platform_testing/ vendor/ cts/ hardware/ prebuilts/ linaro* .repo/local_manifests
cd -
