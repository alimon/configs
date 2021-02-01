#!/bin/bash -xe

vixl_repo="https://github.com/Linaro/vixl.git"

cd vixl/
./tools/test.py --fail-early --nolint --noclang-format
