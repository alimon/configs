#!/bin/bash
set -ex

# We don't build anything so far, just downloading pre-built.
wget https://people.linaro.org/~kevin.townsend/lava/an521_tfm_full.hex -O tfm_full.hex
