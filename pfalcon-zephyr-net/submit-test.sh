#!/bin/sh
set -ex

export PATH=$HOME/.local/bin:$PATH
dir=$(dirname $0)

sudo apt-get -qq -y install jq python3-pip
pip3 install yq

# For now, always check out latest version
rm -rf lite-lava-docker-compose
if [ ! -d lite-lava-docker-compose ]; then
    git clone --depth 1 https://github.com/Linaro/lite-lava-docker-compose
fi

IMAGE_URL="http://snapshots.linaro.org/components/kernel/pfalcon-zephyr-net/${BRANCH}/${PLATFORM}/${BUILD_NUMBER}/samples/net/sockets/dumb_http_server/sample.net.sockets.dumb_http_server/zephyr/zephyr.bin"
JOB_TEMPLATE="lite-lava-docker-compose/example/zephyr-net-ping-frdm_k64f.job"

# Replace image url (passed as docker image command-line arg) in the job
# template.

# "yq" the Python version, https://github.com/kislyuk/yq, requires jq
yq -y ".actions[0].deploy.images.zephyr.url=\"$IMAGE_URL\"" $JOB_TEMPLATE > lava.job

# "yq" the Go version, https://github.com/mikefarah/yq
#wget -q https://github.com/mikefarah/yq/releases/download/3.1.0/yq_linux_amd64
#chmod +x yq_linux_amd64
#./yq_linux_amd64 w lite-lava-docker-compose/example/docker-xilinx-qemu-openamp-echo_test.job actions[1].boot.command $IMAGE_URL > lava.job

python3 $dir/../lite-aeolus-openamp/lava-submit.py lava.job
