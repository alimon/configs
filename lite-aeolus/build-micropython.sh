git clone --depth 1 https://git.linaro.org/lite/zephyr.git zephyr-rtos
(cd zephyr-rtos; git clean -fdx)
. zephyr-rtos/zephyr-env.sh

make -C zephyr BOARD=${PLATFORM}

cd ${WORKSPACE}
mkdir -p out/${PLATFORM}
cp outdir/${PLATFORM}/zephyr.bin out/${PLATFORM}/
