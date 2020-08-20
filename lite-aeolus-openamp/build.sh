#!/bin/bash
set -ex

id

## We don't build anything so far, just downloading pre-built.
#wget -q https://people.linaro.org/~ed.mooring/Images/openamp-image-minimal-zcu102-zynqmp.wic.qemu-sd

mkdir -p openamp
cd openamp

if [ ! -d open-amp ]; then
    git clone https://github.com/OpenAMP/open-amp
else
    (cd open-amp; git pull --rebase)
fi
if [ ! -d libmetal ]; then
    git clone https://github.com/OpenAMP/libmetal
else
    (cd libmetal; git pull --rebase)
fi
if [ ! -d embeddedsw ]; then
    git clone https://github.com/Xilinx/embeddedsw
else
    (cd embeddedsw; git checkout xilinx-v2019.2)
fi

(
    cd open-amp
    echo "GIT_COMMIT=$(git rev-parse --short=8 HEAD)" > ../../env_var_parameters
    echo "EXTERNAL_BUILD_ID=$(git rev-parse --short=8 HEAD)-${BUILD_NUMBER}" >> ../../env_var_parameters
)

cd ..

mkdir -p /home/buildslave/srv/lite-aeolus-openamp/downloads

rm -f xilinx-openamp-build.cid
docker run --cidfile xilinx-openamp-build.cid \
    -v /home/buildslave/srv/lite-aeolus-openamp/downloads:/home/build/prj/build/downloads \
    -v $PWD/openamp:/home/build/prj/openamp \
    pfalcon/xilinx-openamp-build:v3 \
    /bin/bash -c "cd ~/prj; source setupsdk; MACHINE=zcu102-zynqmp bitbake openamp-image-minimal"

rm -rf out
mkdir out
cid=$(cat xilinx-openamp-build.cid)
docker cp -L $cid:/home/build/prj/build/tmp/deploy/images/zcu102-zynqmp/openamp-image-minimal-zcu102-zynqmp.wic.qemu-sd out/
