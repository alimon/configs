#!/bin/sh
set -ex

python3 --version
python3 -c 'import sys; print(sys.path)'

pip3 install --user requests
