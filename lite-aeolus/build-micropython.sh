git clone --depth 1 ${ZEPHYR_GIT_URL} -b ${ZEPHYR_BRANCH} zephyr
west init -l zephyr/
west update
(cd zephyr; git clean -fdx)
. zephyr/zephyr-env.sh


small_rom() {
    echo "arduino_101" | grep -F -w -q "$1"
}

full_testsuite() {
    echo "frdm_k64f" | grep -F -w -q "$1"
}

cd ports/zephyr
if small_rom ${PLATFORM}; then
    ./make-minimal BOARD=${PLATFORM}
elif full_testsuite ${PLATFORM}; then
    ./make-bin-testsuite BOARD=${PLATFORM}
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
cp ports/zephyr/outdir/${PLATFORM}/zephyr/zephyr.bin out/${PLATFORM}/
