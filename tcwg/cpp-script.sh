#!/bin/bash

# Clean: shellcheck -e 2001 ./cpp-script.sh

# NOTE: THIS SCRIPT HAS COPIES IN THE FOLLOWING REPOS:
# - CI/DOCKERFILES.GIT AND
# - CI/JOB/CONFIGS.GIT
# REMEMBER TO SYNCHRONIZE ALL COPIES ON CHANGES.

set -eu -o pipefail

input=""
vars=()

while [ $# -gt 0 ]; do
    case $1 in
	--input|-i) input="$2"; shift ;;
	--var|-v) vars+=("$2"); shift ;;
	*) echo "ERROR: Wrong option: $1"; usage ;;
    esac
    shift
done

if [ x"$input" = x"" ]; then
    echo "ERROR: No --input parameter"
    exit 1
fi

cpp_opts=()
# Undef all macros.  Next loop will define the appropriate ones to "1".
for macro in $(unifdef -s -k -t "$input"); do
    cpp_opts+=("-U${macro}")
done

sed_opts=()
for var in ${vars[@]+"${vars[@]}"}; do
    name=$(echo "$var" | cut -d= -f 1)
    value=$(echo "$var" | cut -s -d= -f 2)
    # Define requested macros to "1".
    cpp_opts+=("-D${name}_${value}=1")
    # Substitute #{NAME} with VALUE.
    sed_opts+=("-e s/#{${name}}/$value/g")
done

unifdef -k -t -x2 "${cpp_opts[@]}" "$input" \
    | sed -e "s/^//" "${sed_opts[@]+"${sed_opts[@]}"}"
