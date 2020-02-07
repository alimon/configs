#!/bin/bash
set -ex

# We don't build anything so far, just downloading pre-built.
wget -q https://people.linaro.org/~ed.mooring/Images/openamp-image-minimal-zcu102-zynqmp.wic.qemu-sd

#echo "GIT_COMMIT=$(git rev-parse --short=8 HEAD)" > env_var_parameters
echo "GIT_COMMIT=mock" > env_var_parameters

mkdir -p /home/buildslave/srv/lite-aeolus-openamp/downloads

docker run pfalcon/xilinx-openamp-build:v1 echo done
