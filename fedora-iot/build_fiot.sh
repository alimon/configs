#!/bin/sh

set -e

IMG="Fedora-IoT-30-20190515.1.x86_64.raw.xz"
URL="https://dl.fedoraproject.org/pub/alt/iot/30/IoT/x86_64/images"
wget -c ${URL}/${IMG}
xz -d ${IMG}

sudo ./guestfish_x86.sh

echo "build complete"

