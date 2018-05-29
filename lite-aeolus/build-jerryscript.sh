git clone --depth 1 ${ZEPHYR_GIT_URL} -b ${ZEPHYR_BRANCH} zephyr
(cd zephyr; git clean -fdx)
. zephyr/zephyr-env.sh

make -f ./targets/zephyr/Makefile.zephyr BOARD=${PLATFORM}

cd ${WORKSPACE}
mkdir -p out/${PLATFORM}
cp build/${PLATFORM}/zephyr/zephyr/zephyr.bin out/${PLATFORM}/
