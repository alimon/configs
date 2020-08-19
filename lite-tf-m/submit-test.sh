#!/bin/sh
set -ex

export PATH=$HOME/.local/bin:$PATH
dir=$(dirname $0)

sudo apt-get -qq -y install jq python3-pip
# "yq" the Python version, https://github.com/kislyuk/yq, requires jq
# Used to replace image url in the job template.
pip3 install yq

# "yq" the Go version, https://github.com/mikefarah/yq
#wget -q https://github.com/mikefarah/yq/releases/download/3.1.0/yq_linux_amd64
#chmod +x yq_linux_amd64
#./yq_linux_amd64 w lite-lava-docker-compose/example/docker-xilinx-qemu-openamp-echo_test.job actions[1].boot.command $IMAGE_URL > lava.job

# For now, always check out latest version
rm -rf lite-lava-docker-compose
if [ ! -d lite-lava-docker-compose ]; then
    git clone --depth 1 https://github.com/Linaro/lite-lava-docker-compose
fi

IMAGE_URL="http://snapshots.linaro.org/components/kernel/aeolus-2/tf-m/${BRANCH}/${PLATFORM}/${BUILD_NUMBER}/tfm_full.hex"
#IMAGE_URL="https://people.linaro.org/~kevin.townsend/lava/an521_tfm_full.hex"

JOB_TEMPLATE="lite-lava-docker-compose/example/tfm-regression-qemu.job"
yq -y ".actions[0].deploy.images.tfm.url=\"$IMAGE_URL\"" $JOB_TEMPLATE > lava.job
python3 $dir/../../lite-build-tools/lava_submit.py lava.job
echo
