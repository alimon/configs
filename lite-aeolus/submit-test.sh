#!/bin/sh
set -ex

dir=$(dirname $0)

python3 template-jobdef.py "$1" >jobdef.$$
cat jobdef.$$
python3 $dir/../../lite-build-tools/lava_submit.py jobdef.$$
