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

tmp_in=$(mktemp)
tmp_out=$(mktemp)
cp "$input" "$tmp_in"

# Iteratively include files until there are no more #include directives.
while grep -q "^#include .*\$" "$tmp_in"; do
    include=$(grep "^#include .*\$" "$tmp_in" | head -n1)
    inc_file=$(echo "$include" | sed -e "s/^#include \+//")
    if [ ! -f "$inc_file" ]; then
	echo "ERROR: #include file $inc_file does not exist" >&2
	exit 1
    fi
    # Escape '/' in the path name
    include=$(echo "$include" | sed -e "s#/#\\\\/#g")
    # Instruct sed to read in the include and add extra '#' to #include line.
    cat "$tmp_in" | sed -e "/^$include\$/ {
i #BEGIN: $inc_file
r $inc_file
a #END:   $inc_file
d
}" > "$tmp_out"
    cp "$tmp_out" "$tmp_in"
done

cpp_opts=()
# Undef all macros.  Next loop will define the appropriate ones to "1".
for macro in $(unifdef -s -k -t "$tmp_in"); do
    cpp_opts+=("-U${macro}")
done

declare -Ag vars_values
if [ ${#vars[@]} -gt 0 ]; then
    for var in "${vars[@]}"; do
	name=$(echo "$var" | cut -d= -f 1)
	value=$(echo "$var" | cut -s -d= -f 2)

	# Define requested macros to "1".
	cpp_opts+=("-D${name}_${value}=1")

	# Gather all values for $name in $vars_values[$name]
	if [ x"${vars_values[$name]+set}" = x"set" ]; then
            vars_values[$name]="${vars_values[$name]} $value"
	else
            vars_values[$name]="$value"
	fi
    done
fi

sed_opts=()
for name in "${!vars_values[@]}"; do
    # Substitute #{NAME} with VALUE.
    sed_opts+=("-e" "s/#{${name}}/${vars_values[$name]}/g")
done

unifdef -k -t -x2 "${cpp_opts[@]}" "$tmp_in" \
    | sed -e "s/^//" "${sed_opts[@]+"${sed_opts[@]}"}"
