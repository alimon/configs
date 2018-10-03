#!/bin/bash

cat > ${WORKSPACE}/BUILD-INFO.txt << EOF
Format-Version: 0.5

Files-Pattern: *
License-Type: protected
Auth-Groups: ${AUTH_GROUPS}
EOF
