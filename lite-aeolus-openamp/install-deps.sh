#!/bin/sh
set -ex

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qq update
sudo apt-get -qq -y install jq python3-pip
pip3 install yq
