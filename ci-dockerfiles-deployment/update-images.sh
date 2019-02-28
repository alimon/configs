#!/bin/bash -e

cd dockerfiles/

images_to_update=""

# find out which images haven't had any commits in the last 30 days

for dir in ./*/; do
    shortdir=$(basename $dir)
    # Skip toolchain images
    echo $shortdir|grep -q tcwg && continue
    # not an image dir
    [ -x $shortdir/build.sh ]||continue
    changed=$(git log -1 --oneline --since "1 month" ${shortdir}|wc -l)
    if [ $changed -eq 1 ]; then
        echo "new: $shortdir"
    else
        echo "nothing new: $shortdir"
        images_to_update="$images_to_update $shortdir"
    fi
done

echo $images_to_update

# trigger builds for every non-updated image over the http api
for image in $images_to_update
do
    arch=$(echo ${image} | cut -f2 -d '-')
    if [ "$arch" = "aarch64" ]; then
        arch=arm64
    fi
    if [ "$arch" = "amd64" -o "$arch" = "arm64" -o "$arch" = "armhf" ]; then
        cat > ../docker_${image}_build.txt << EOF
nodelabel=build-${arch}
image=${image}
EOF
    else
        echo "unknown arch: $arch in $image"
    fi
done

