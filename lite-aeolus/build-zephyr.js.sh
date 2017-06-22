. deps/zephyr/zephyr-env.sh
. ./zjs-env.sh
make BOARD=${PLATFORM}

cd ${WORKSPACE}
mkdir -p out/${PLATFORM}
cp outdir/${PLATFORM}/zephyr.bin out/${PLATFORM}/
