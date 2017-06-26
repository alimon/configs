git clone --depth 1 https://git.linaro.org/lite/zephyr.git zephyr-rtos
(cd zephyr-rtos; git clean -fdx)
. zephyr-rtos/zephyr-env.sh


small_rom() {
    echo "arduino_101" | grep -F -w -q "$1"
}

cd zephyr
if small_rom ${PLATFORM}; then
    ./make-minimal BOARD=${PLATFORM}
else
    make BOARD=${PLATFORM}
fi

if [ ${PLATFORM} = "qemu_x86" ]; then
    rm -f /tmp/slip.sock
    (socat PTY,link=/tmp/slip.dev UNIX-LISTEN:/tmp/slip.sock &)
    make BOARD=${PLATFORM} test
fi

cd ${WORKSPACE}
mkdir -p out/${PLATFORM}
cp zephyr/outdir/${PLATFORM}/zephyr.bin out/${PLATFORM}/
