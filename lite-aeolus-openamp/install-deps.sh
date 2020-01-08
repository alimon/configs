#!/bin/sh
set -ex

sudo apt update
sudo apt install -y jq
pip install yq
