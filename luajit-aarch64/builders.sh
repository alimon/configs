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

# Build and install
safe make CCDEBUG="-DUSE_LUA_ASSERT" PREFIX="${WORKSPACE}"/install install -j "$(njobs)"
safe export LUA_PATH="$(ls -d "${WORKSPACE}"/install/share/luajit*)/?.lua;;"

# Run a simple test
safe ./src/luajit -jdump -e "x=0; for i=1,100 do x=x+i end; print(x)"

# Additional internal test which doesn't exist everywhere
if make -n test > /dev/null; then
  safe make test
fi
