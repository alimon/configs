#!/bin/bash

# Submit QEMU jobs
case "${MACHINE}" in
#  hikey)
#    DEVICE_TYPE=qemu_arm64
#    ;;
  intel-core2-32)
    DEVICE_TYPE=qemu_x86_64
    ;;
  *)
    unset DEVICE_TYPE
    ;;
esac

echo "DEVICE_TYPE=${DEVICE_TYPE}" > qemu_device_type_parameters

