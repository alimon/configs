make -f ./targets/zephyr/Makefile.zephyr BOARD=${PLATFORM}

cd ${WORKSPACE}
mkdir -p out/${PLATFORM}
cp build/$(BOARD)/zephyr/zephyr.bin out/${PLATFORM}/
