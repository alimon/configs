#!/bin/bash
set -ex

id

## We don't build anything so far, just downloading pre-built.
#wget -q https://people.linaro.org/~ed.mooring/Images/openamp-image-minimal-zcu102-zynqmp.wic.qemu-sd

#echo "GIT_COMMIT=$(git rev-parse --short=8 HEAD)" > env_var_parameters
echo "GIT_COMMIT=mock" > env_var_parameters

mkdir -p /home/buildslave/srv/lite-aeolus-openamp/downloads

docker run --cidfile xilinx-openamp-build.cid \
    -v /home/buildslave/srv/lite-aeolus-openamp/downloads:/home/build/prj/build/downloads \
    pfalcon/xilinx-openamp-build:v2 \
    /bin/bash -c "cd ~/prj; source setupsdk; MACHINE=zcu102-zynqmp bitbake openamp-image-minimal"

cid=$(cat xilinx-openamp-build.cid)
docker cp -L $cid:/home/build/prj/build/tmp/deploy/images/zcu102-zynqmp/openamp-image-minimal-zcu102-zynqmp.wic.qemu-sd .
