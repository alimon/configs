#!/bin/bash

set -e
echo "dist: $dist"
echo "source: $source"
echo "repo: $repo"
echo "appendversion: $appendversion"
obsrepo=$repo-$dist
rm -rf *

dget -q -d -u $source
sourcename=`basename $source|sed -e 's,_.*,,'`
echo "will send to OBS: $obsrepo $sourcename"

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
    dch --force-distribution -m -D $dist -llinaro$dist "Linaro CI build: $deltatype"
    dpkg-buildpackage -S -d
    cd ..
fi

dsc=`ls -tr *dsc`

# update existing package
if osc co $obsrepo $sourcename; then
    rm -v $obsrepo/$sourcename/$sourcename*||true
else
    osc co $obsrepo
    mkdir -p $obsrepo/$sourcename
    osc add $obsrepo/$sourcename
fi
for file in `dcmd $dsc`;
do
    cp $file $obsrepo/$sourcename
done

osc addremove $obsrepo/$sourcename
osc ci $obsrepo/$sourcename -m "$BUILD_URL"
