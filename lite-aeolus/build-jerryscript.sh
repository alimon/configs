git clone --depth 1 https://git.linaro.org/lite/zephyr.git
(cd zephyr; git clean -fdx)
. zephyr/zephyr-env.sh

make -f ./targets/zephyr/Makefile.zephyr BOARD=${PLATFORM}

cd ${WORKSPACE}
mkdir -p out/${PLATFORM}
cp build/${PLATFORM}/zephyr/zephyr.bin out/${PLATFORM}/
