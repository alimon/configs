#!/bin/sh
set -ex

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qq update

# Show filesystem layout and space
df -h

# List available toolchains
ls -l ${HOME}/srv/toolchain/
