#!/bin/bash

# Mapping for MACHINE -> DEVICE_TYPE
case "${MACHINE}" in
  am57xx-evm)
    DEVICE_TYPE=x15
    ;;
  dragonboard-410c)
    DEVICE_TYPE=dragonboard-410c
    ;;
  hikey)
    DEVICE_TYPE=hi6220-hikey-r2
    ;;
  intel-core2-32)
    DEVICE_TYPE=i386
    ;;
  intel-corei7-64)
    DEVICE_TYPE=x86
    ;;
  juno)
    DEVICE_TYPE=juno
    ;;
  stih410-b2260)
    DEVICE_TYPE=b2260
    ;;
  *)
    echo "Skip DEVICE_TYPE for ${MACHINE}"
    ;;
esac

echo "DEVICE_TYPE=${DEVICE_TYPE}" > device_type_parameters
