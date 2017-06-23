git clone --depth 1 https://git.linaro.org/lite/zephyr.git zephyr-rtos
(cd zephyr-rtos; git clean -fdx)
. zephyr-rtos/zephyr-env.sh


small_rom() {
    echo "arduino_101 foo_bar" | grep -F -w -q "$1"
}

cd zephyr
if small_rom $1; then
    ./make-minimal BOARD=${PLATFORM}
else
    make BOARD=${PLATFORM}
fi


cd ${WORKSPACE}
mkdir -p out/${PLATFORM}
cp zephyr/outdir/${PLATFORM}/zephyr.bin out/${PLATFORM}/
