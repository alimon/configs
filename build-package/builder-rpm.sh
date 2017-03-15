#!/bin/bash

echo "source: $source"
echo "repo: $repo"

wget --progress=dot -e dotbytes=2M $source
sourcefile="*.src.rpm"
sourcename=`rpm -q --queryformat '%{NAME}' -p ${sourcefile}`

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
