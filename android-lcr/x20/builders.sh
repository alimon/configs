# Early test
if [ ! -f build-configs/${BUILD_CONFIG_FILENAME} ]; then
  echo "No config file named ${BUILD_CONFIG_FILENAME} exists"
  echo "in android-build-configs.git"
  exit 1
fi

# Clean android-patchsets and repositories in device
rm -rf build/out build/android-patchsets build/device

mkdir -p build/

# Build Android
build-tools/node/build us-east-1.ec2-git-mirror.linaro.org "${CONFIG}"
cp -a /home/buildslave/srv/${BUILD_DIR}/build/out/*.json /home/buildslave/srv/${BUILD_DIR}/build/out/*.xml ${WORKSPACE}/

cd build/out
rm -f ramdisk.img
for image in "boot.img" "system.img" "userdata.img" "cache.img"; do
  echo "Compressing ${image}"
  xz ${image}
done
cd -

rm -rf build/out/BUILD-INFO.txt
wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/x20/build-info/template.txt -O build/out/BUILD-INFO.txt

# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
PUB_SRC=${PWD}/build/out
PUB_DEST=/android/${JOB_NAME}/${BUILD_NUMBER}
EOF
