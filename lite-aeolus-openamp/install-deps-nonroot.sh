#!/bin/sh
set -ex

python3 --version
python3 -c 'import sys; print(sys.path)'

pip install --user requests
