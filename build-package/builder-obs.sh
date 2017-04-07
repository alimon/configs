#!/bin/bash

set -e
echo "source: $source"
echo "repo: $repo"
echo "appendversion: $appendversion"

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
then
    echo apt-get update error try again in a moment
    sleep 15
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -q||true
fi

sudo DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -q osc

dget -q -d -u $source
sourcename=`basename $source|sed -e 's,_.*,,'`
echo "will send to OBS: $repo $sourcename"

if [ "$backport" = "true" ]; then
   appendversion=true
   deltatype=backport
fi

if [ "$appendversion" = "true" ]; then
    dpkg-source -x *.dsc work/
    rm *.dsc
    cd work
    dpkg-parsechangelog
    maint=`dpkg-parsechangelog -SMaintainer`
    if [[ $maint != *linaro* ]]; then
       echo "Warning not a linaro maintainer: $maint"
       export maint="packages@lists.linaro.org"
    fi

    # Changelog update
    change=`dpkg-parsechangelog -SChanges`
    case $change in
        *Initial*release*)
            deltatype="new package"
            ;;
        *Backport*from*|*Rebuild*for*)
            deltatype="backport"
            ;;
        *Added*patch*)
            deltatype="patched"
            ;;
        *Upstream*snapshot*)
            deltatype="snapshot"
            ;;
        *HACK*)
            deltatype="hack"
            ;;
        *)
            deltatype="other"
            ;;
    esac
    dch --force-distribution -m -llinaro "Linaro CI build: $deltatype"
    dpkg-buildpackage -S -d
    cd ..
fi

dsc=`ls -tr *dsc`

cat > $HOME/.oscrc <<EOF
[general]
apiurl = https://obs.linaro.org

[https://obs.linaro.org]
user=$OSCRC_USER
pass=$OSCRC_PASS
EOF

# update existing package
if osc co $repo $sourcename; then
    rm -v $repo/$sourcename/${sourcename}_*||true
else
    osc co $repo
    mkdir -p $repo/$sourcename
    osc add $repo/$sourcename
fi
for file in `dcmd $dsc`;
do
    cp $file $repo/$sourcename
done

osc addremove $repo/$sourcename
osc ci $repo/$sourcename -m "$BUILD_URL"
