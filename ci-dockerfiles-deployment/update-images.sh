#!/bin/bash -e

git clone --depth 1 https://git.linaro.org/ci/dockerfiles.git
cd dockerfiles/

images_to_update=""

# find out which images haven't had any commits in the last 30 days

for dir in ./*/; do
    shortdir=$(basename $dir)
    # Skip toolchain images
    echo $shortdir|grep -q tcwg && continue
    # not an image dir
    [ -x $shortdir/build.sh ]||continue
    pushd $shortdir >/dev/null
    if find -mtime -30|grep -q "."; then
        echo "new: $shortdir"
    else
        echo "nothing new: $shortdir"
        images_to_update="$images_to_update $shortdir"
    fi
    popd > /dev/null
done

echo $images_to_update

# trigger builds for every non-updated image over the http api
for image in $images_to_update
do
    nodelabel="build-$(echo $image | cut -f2 -d '-')"
    echo curl -X POST "https://${BOTUSER}:${APITOKEN}@ci.linaro.org/job/ci-dockerfile-build/buildWithParameters?nodelabel=${nodelabel}&image=${image}"
done


