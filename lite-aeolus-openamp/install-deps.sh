#!/bin/sh
set -ex

sudo apt update
sudo apt -q=2 -y install jq python3-pip
pip3 install yq
