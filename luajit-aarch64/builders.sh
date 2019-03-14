#!/bin/bash

########## Helper functions ##########

# Message prefix
_msg_prefix () {
  echo "[$(date +%H:%M:%S)]$(hostname):"
}

# Report a message
msg () {
  echo "$(_msg_prefix):MSG: $*"
}

# Report an error and terminate the script
err () {
  echo "$(_msg_prefix):ERR: $*"
  exit 1
}

# Verbose-debug message
dbg () {
  # Don't print debug message if CI_DEBUG is 'false'.
  if [ "$CI_DEBUG" = "false" ]; then
    return
  fi
  echo "$(_msg_prefix):DBG: $*"
}

# run [command] [args ...]
run () {
  dbg Running : "$@"
  "$@"
}

# 'safe [command]' executes [command] and terminates if the exit code is
# nonzero. An alternative to "set -e"
safe () {
  run "$@"
  local err_num=$?
  if [ $err_num -ne 0 ]; then
    err "Error [$err_num] while doing [$*]"
  fi
}

# Suggested number of parallel tasks
njobs () {
  local cpus=$(nproc)
  if [ $cpus -le 1 ]; then
    echo 1
  else
    echo $(($cpus - 1))
  fi
}

########## LuaJIT build and test ##########

arch=$(uname -m)

case $arch in
x86_64)
	arch=x86
	;;
armhf)
	arch=arm
	;;
aarch64)
	arch=arm64
	;;
*)
	err "No nodes to build for this architecture ($arch)"
	;;
esac

# Build and install
THISBUILDDIR="${WORKSPACE}/build${BUILD_NUMBER}"
safe mkdir -p "$THISBUILDDIR"/dump
safe make CCDEBUG="-DUSE_LUA_ASSERT" PREFIX="$THISBUILDDIR"/install install -j "$(njobs)"
safe ln -sf "$THISBUILDDIR"/install/bin/luajit-* "$THISBUILDDIR"/install/bin/luajit
safe export LUA_PATH="$(ls -d "$THISBUILDDIR"/install/share/luajit*)/?.lua;;"
# Run a simple test
safe ./src/luajit -jdump -e "x=0; for i=1,100 do x=x+i end; print(x)"

TESTSUITE_GIT_URL=https://github.com/SameeraDes/LuaJIT-test-cleanup.git

safe cd $THISBUILDDIR
safe git clone $TESTSUITE_GIT_URL LuaJIT-testsuite
safe cd LuaJIT-testsuite/test
safe "$THISBUILDDIR"/install/bin/luajit test.lua

safe cd $THISBUILDDIR/LuaJIT-testsuite/bench

while IFS=" " read -r bench opts rest; do
	if [[ "$rest" = "" ]] ; then
		x=`{ time "$THISBUILDDIR"/install/bin/luajit  $bench.lua $opts > "$THISBUILDDIR"/dump/perf_$bench.dmp ; } 2>&1 | grep "real" | cut -f 2`
	else
		x=`{ time "$THISBUILDDIR"/install/bin/luajit  $bench.lua $opts < $rest > "$THISBUILDDIR"/dump/perf_$bench.dmp ; } 2>&1 | grep "real" | cut -f 2`
	fi
	echo $bench": " $x
done < PARAM_${arch}.txt > "$THISBUILDDIR"/dump/bench.txt

safe cat "$THISBUILDDIR"/dump/bench.txt
rm $THISBUILDDIR -rf

### Additional internal test which doesn't exist everywhere
##if make -n test > /dev/null; then
##  safe make test
##fi
