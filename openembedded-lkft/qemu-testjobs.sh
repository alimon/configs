#!/bin/bash

# Submit QEMU jobs
case "${MACHINE}" in
# Disable arm32 until issues are resolved.
# https://projects.linaro.org/browse/CTT-1169
#  am57xx-evm)
#    DEVICE_TYPE=qemu_arm
#    ;;
  hikey)
    DEVICE_TYPE=qemu_arm64
    ;;
  intel-core2-32)
    DEVICE_TYPE=qemu_x86_64
    ;;
  *)
    unset DEVICE_TYPE
    ;;
esac

echo "DEVICE_TYPE=${DEVICE_TYPE}" > qemu_device_type_parameters

