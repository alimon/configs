. deps/zephyr/zephyr-env.sh
. ./zjs-env.sh
make BOARD=${PLATFORM}

cd ${WORKSPACE}
mkdir -p out/${PLATFORM}
# Copy .bin/.elf
cp outdir/${PLATFORM}/zephyr/zephyr.[be]* out/${PLATFORM}/
