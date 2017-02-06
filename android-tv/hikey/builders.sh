# Build Android
rm -rf build/out build/android-patchsets build/device/linaro/hikey
mkdir -p build/
cd build/
wget https://dl.google.com/dl/android/aosp/linaro-hikey-20160226-67c37b1a.tgz
tar -xvf linaro-hikey-20160226-67c37b1a.tgz
yes "I ACCEPT" | ./extract-linaro-hikey.sh
cd -

build-tools/node/build us-east-1.ec2-git-mirror.linaro.org "${CONFIG}"
cp -a /home/buildslave/srv/${BUILD_DIR}/build/out/*.json /home/buildslave/srv/${BUILD_DIR}/build/out/*.xml ${WORKSPACE}/

# Build Live TV app
cd build/
source build/envsetup.sh
tapas LiveTv arm64
make LiveTv
cp -r out/target/product/generic_arm64/system//priv-app/LiveTv/ out/system/priv-app/
rm -rf out/target
cd -

mkdir -p apps/
cd apps/
export ANDROID_HOME=/home/buildslave/srv/android-sdk/
mkdir -p /home/buildslave/.android/
echo "count=0" > /home/buildslave/.android/repositories.cfg

rm -rf ExoPlayer androidtv-sample-inputs

mkdir -p /home/buildslave/srv/${BUILD_DIR}/build/out/data/app/

git clone https://github.com/googlesamples/androidtv-sample-inputs
cd androidtv-sample-inputs/
sed -i "s/23.0.3/25.0.2/g" app/build.gradle library/build.gradle
./gradlew assembleDebug
cp app/build/outputs/apk/app-debug.apk /home/buildslave/srv/${BUILD_DIR}/build/out/data/app/
cd -

git clone https://github.com/google/ExoPlayer
cd ExoPlayer
sed -i "s/23.0.3/25.0.2/g" build.gradle
./gradlew assembleDebug
cp ./demo/buildout/outputs/apk/demo-withExtensions-debug.apk /home/buildslave/srv/${BUILD_DIR}/build/out/data/app/
cd -

# Compress images
cd /home/buildslave/srv/${BUILD_DIR}/build/out
host/linux-x86/bin/make_ext4fs -s -T -1 -S root/file_contexts -L data -l 5588893184 -a data userdata.img data
host/linux-x86/bin/make_ext4fs -s -T -1 -S root/file_contexts.bin -L system -l 1610612736 -a system system.img system system
host/linux-x86/bin/make_ext4fs -s -T -1 -S root/file_contexts -L data -l 1342177280 -a data userdata-4gb.img data

rm -f ramdisk.img
for image in "boot.img" "boot_fat.uefi.img" "system.img" "userdata.img" "userdata-4gb.img" "cache.img"; do
  echo "Compressing ${image}"
  xz ${image}
done

rm -rf BUILD-INFO.txt
wget https://git.linaro.org/ci/job/configs.git/blob_plain/HEAD:/android-lcr/hikey/build-info/aosp-master-template.txt -O BUILD-INFO.txt

# Publish parameters
cat << EOF > ${WORKSPACE}/publish_parameters
PUB_SRC=${PWD}
PUB_DEST=/android/${JOB_NAME}/${BUILD_NUMBER}
EOF
