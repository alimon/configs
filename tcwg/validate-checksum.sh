#!/bin/bash

# NOTE: THIS SCRIPT HAS COPIES IN THE FOLLOWING REPOS:
# - CI/DOCKERFILES.GIT AND
# - CI/JOB/CONFIGS.GIT
# REMEMBER TO SYNCHRONIZE ALL COPIES ON CHANGES.

set -eu

generate=false

usage ()
{
    echo "Syntax: $0 [--generate true/false] <generated_file>" 1>&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
	--generate) generate="$2"; shift ;;
	--*) echo "ERROR: Wrong option: $1"; usage ;;
	*) break ;;
    esac
    shift
done

if [ x"${1+set}" != x"set" ]; then
    usage
fi

GENED_FILE="$1"

if $generate; then
    MD5=$(md5sum "$GENED_FILE" | awk '{ print $1; }')
    echo "# checksum: $MD5" >> "$GENED_FILE"
else
    EXPECTED_MD5=$(tail -n1 "$GENED_FILE" | awk '{ print $3; }')
    ACTUAL_MD5=$(head -n -1 "$GENED_FILE" | md5sum | awk '{ print $1; }')

    if [ "$EXPECTED_MD5" != "$ACTUAL_MD5" ]; then
	echo "ERROR: $GENED_FILE has been modified since it was auto-generated."
	echo "Note: Current dir is $(pwd)"
	exit 1
    fi
fi
