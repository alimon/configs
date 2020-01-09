#!/bin/sh
set -ex

export PATH=$HOME/.local/bin:$PATH
dir=$(dirname $0)

if [ ! -d lite-lava-docker-compose ]; then
    git clone https://github.com/Linaro/lite-lava-docker-compose
fi

IMAGE_URL="http://snapshots.linaro.org/components/kernel/aeolus-2/openamp/${BRANCH}/${PLATFORM}/${BUILD_NUMBER}/openamp-image-minimal-zcu102-zynqmp.wic.qemu-sd"

# Replace image url (passed as docker image command-line arg) in the job
# template. "yq" tools is used, https://github.com/kislyuk/yq (note:
# there're different yq's around, we used Python wrapper around jq).
yq -y ".actions[1].boot.command=\"$IMAGE_URL\"" lite-lava-docker-compose/example/docker-xilinx-qemu-openamp-echo_test.job > lava.job

python3 $dir/lava-submit.py lava.job
