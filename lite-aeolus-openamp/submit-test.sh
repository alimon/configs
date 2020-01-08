#!/bin/sh
set -ex

dir=$(dirname $0)

if [ ! -d lite-lava-docker-compose ]; then
    git clone https://github.com/Linaro/lite-lava-docker-compose
fi

python3 $dir/lava-submit.py lite-lava-docker-compose/example/docker-xilinx-qemu-openamp-echo_test.job
