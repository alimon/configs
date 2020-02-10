#!/bin/sh
set -ex

python3 -m ensurepip --user
python3 -m pip --help
pip3 install --user requests
