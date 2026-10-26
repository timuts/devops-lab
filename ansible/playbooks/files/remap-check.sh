#!/bin/bash
#
# Check if any UIDs or GIDs are outside the range in /etc/sub{uid,gid}
#

set -eu
set -o pipefail
set -o errtrace

function print_stack() {
    # Default of 1 means skip the first frame to ignore this function.
    local skip="${1:-1}"

    # Minus one to ignore the call to main() at the end of this file.
    local i
    for ((i = $skip; i < ${#FUNCNAME[@]} - 1; i++)); do
        echo "  at ${FUNCNAME[$i]}() in ${BASH_SOURCE[$i]}:${BASH_LINENO[$i-1]}"
    done
}

function fatal() {
  local msg="$1"
  echo "FATAL: $msg" >&2
  print_stack 2
  exit 1
}

function main() {
  trap 'print_stack' ERR
  
  if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <container_root_directory>" >&2
    exit 1
  fi

  if ! [[ -d "$1" ]]; then
    fatal "Not a directory: $1"
  fi
  
  croot=$(readlink -f "$1")
  chost=$(basename "$croot")
  
  read first_id num_ids \
    < <(sed -En "s/^$chost:([0-9]+):([0-9]+)\$/\\1 \\2/p; T; q" /etc/sub{uid,gid})
  
  if [[ -z "$first_id" ]] || [[ -z "$num_ids" ]]; then
    fatal "Can't find '$chost' in /etc/sub{uid,gid}."
  fi
  
  all_ids=$(find "$croot" -xdev -printf "%U\n%G\n" | sort -u)
  if [[ -z "$all_ids" ]]; then
    fatal "No files found in '$croot'."
  fi
  
  last_id=$((first_id + num_ids - 1))
  for id in $all_ids; do
    if [[ "$id" -lt "$first_id" ]] || \
       [[ "$id" -gt "$last_id" ]]; then
      fatal "ID found outside the range. $first_id <= $id <= $last_id is false."
    fi
  done
  
  echo "OK"
}

main "$@"
