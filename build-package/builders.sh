#!/bin/bash

set -e
cat > repo.parameters << EOF
build_success=false
pkg_build_url=${BUILD_URL}
EOF

dist=`lsb_release -sc`
# lsb doesn't give stretch codename until release
[ "$dist" = "n/a" ] && dist=stretch
if [ "$dist" != "$codename" ]
then
    echo "$codename requested while we are $dist, skip"
    exit 0
fi
arch=`dpkg-architecture -qDEB_HOST_ARCH`
# arm64 is the must build target with source uploads for all dists
if [ $arch = arm64 ]
then
    buildpackage_params="-sa"
else
    buildpackage_params="-B"
fi
[ $arch = armhf ] && personality=linux32

echo "arch: $arch"
echo "dist: $dist"
echo "source: $source"
echo "repo: $repo"
echo "appendversion: $appendversion"

sudo rm -rf *.changes repo work /etc/apt/sources.list.d/local.list
# build a source repo for apt-get build-dep
mkdir repo && cd repo
dget -q -d -u $source
dpkg-scansources . /dev/null > Sources.gz
echo "deb-src file:$(pwd) /" > local.list
echo "deb http://repo.linaro.org/ubuntu/linaro-overlay ${dist} main" >> local.list
if [ "${repo}" != "linaro-overlay" ]; then
    echo "deb http://repo.linaro.org/ubuntu/${repo} ${dist} main" >> local.list
fi
sudo cp local.list /etc/apt/sources.list.d/
if [ "$dist == jessie" ]
then
   cat > backports.pref <<EOF
Package: *
Pin: release a=jessie-backports
Pin-Priority: 500
EOF
   sudo cp backports.pref /etc/apt/preferences.d/
fi
cd ..
localdsc=`echo $source|sed -e "s,.*/,$(pwd)/repo/,"`
sourcename=`basename ${localdsc}|sed -e 's,_.*,,'`

dpkg-source -x ${localdsc} work/
# Verify entries
cd work
dpkg-parsechangelog
maint=`dpkg-parsechangelog -SMaintainer`
if [[ $maint != *linaro* ]]; then
   echo "Warning not a linaro maintainer: $maint"
   export maint="packages@lists.linaro.org"
fi
echo email=$maint >> ../repo.parameters
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
if [ "$backport" = "true" ]; then
   appendversion=true
   deltatype=backport
fi
# Changelog update
if [ "$appendversion" = "true" ]; then
   dch --force-distribution -m -D $dist -llinaro$dist "Linaro CI build: $deltatype"
elif [ `dpkg-parsechangelog -SDistribution` != $dist ]; then
   echo "Wrong distribution in changelog, setting to: $dist"
   dch --force-distribution -m -D $dist -a "Linaro CI: set distribution to $dist"
fi

DEBIAN_FRONTEND=noninteractive
echo exit 101 | sudo tee /usr/sbin/policy-rc.d
sudo chmod +x /usr/sbin/policy-rc.d
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
then
    echo apt-get update error try again in a moment
    sleep 15
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -q||true
fi
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -uqq
then
    echo apt-get dist-upgrade error try again in a moment
    sleep 15
    sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -uq||true
fi
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get build-dep -qq --no-install-recommends -y ${sourcename}
then
    echo apt-get build-dep error try again in a moment
    sleep 15
    sudo DEBIAN_FRONTEND=noninteractive apt-get build-dep -q --no-install-recommends -y ${sourcename}
fi

export DEB_BUILD_OPTIONS=parallel=`getconf _NPROCESSORS_ONLN`

$personality dpkg-buildpackage -rfakeroot $buildpackage_params
cd ..

ls -l .
change=`echo *changes`
if [ ! -r $change ]
then
    echo "no changes file"
    exit 1
else
    cat $change
fi
cat > repo.parameters << EOF
build_success=true
pkg_job_name=${JOB_NAME}
key_id=B86C70FE
pkg_changes=${change}
host_ppa=${repo}
pkg_build_url=${BUILD_URL}
email=$maint
EOF
