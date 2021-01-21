#!/bin/bash

set -ex

sudo apt-get update
sudo apt-get install -y ccache bc kmod cpio chrpath gawk texinfo libsdl1.2-dev whiptail diffstat libssl-dev build-essential libgmp-dev libmpc-dev
