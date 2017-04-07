#!/bin/bash

set -e
echo "source: $source"
echo "repo: $repo"

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
then
    echo apt-get update error try again in a moment
    sleep 15
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -q||true
fi

sudo DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -q osc rpm rpm2cpio cpio

wget --progress=dot -e dotbytes=2M $source
sourcefile="*.src.rpm"
sourcename=`rpm -q --queryformat '%{NAME}' -p ${sourcefile}`

cat > $HOME/.oscrc <<EOF
[general]
apiurl = https://obs.linaro.org

[https://obs.linaro.org]
user=$OSCRC_USER
pass=$OSCRC_PASS
EOF

# update existing package
if osc co $repo $sourcename; then
    rm -v $repo/$sourcename/*||true
else
    osc co $repo
    mkdir -p $repo/$sourcename
    osc add $repo/$sourcename
fi
(
cd $repo/$sourcename
rpm2cpio ../../$sourcefile|cpio --extract --make-directories --verbose
)

osc addremove $repo/$sourcename
osc ci $repo/$sourcename -m "$BUILD_URL"
