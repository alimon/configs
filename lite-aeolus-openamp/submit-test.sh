#!/bin/sh
set -ex

export PATH=$HOME/.local/bin:$PATH
dir=$(dirname $0)

# For now, always check out latest version
rm -rf lite-lava-docker-compose
if [ ! -d lite-lava-docker-compose ]; then
    git clone https://github.com/Linaro/lite-lava-docker-compose
fi

IMAGE_URL="http://snapshots.linaro.org/components/kernel/aeolus-2/openamp/${BRANCH}/${PLATFORM}/${BUILD_NUMBER}/openamp-image-minimal-zcu102-zynqmp.wic.qemu-sd"

# Replace image url (passed as docker image command-line arg) in the job
# template.

# "yq" the Python version, https://github.com/kislyuk/yq, requires jq
#yq -y ".actions[1].boot.command=\"$IMAGE_URL\"" lite-lava-docker-compose/example/docker-xilinx-qemu-openamp-echo_test.job > lava.job

# "yq" the Go version, https://github.com/mikefarah/yq
wget -q https://github.com/mikefarah/yq/releases/download/3.1.0/yq_linux_amd64
chmod +x yq_linux_amd64
./yq_linux_amd64 w lite-lava-docker-compose/example/docker-xilinx-qemu-openamp-echo_test.job actions[1].boot.command $IMAGE_URL > lava.job

cat lava.job
python3 $dir/../../lite-build-tools/lava_submit.py lava.job
