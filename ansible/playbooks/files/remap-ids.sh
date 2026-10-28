#!/bin/bash
#
# Remap UID/GID ownership, adding the specified number to each.
#
# For setting up a user namespace container filesystem with mapped IDs.
#

set -eu
set -o pipefail
set -o errtrace

MIN_ID=2000544
MAX_ID=8554044
MIN_MAP_ID=100000
FORCE=no
REMAP_CHECK="$(dirname "$BASH_SOURCE")/remap-check.sh"

function check_root_dir() {
  local croot="$1"

  if [[ "$(readlink -f "$croot")" == / ]]; then
    echo "ERROR: Refusing to change host root directory." >&2
    exit 1
  fi

  if [[ "$(dirname "$croot")" != /var/lib/machines ]]; then
    echo "ERROR: Container root directory must be in /var/lib/machines" >&2
    exit 1
  fi

  if ! [[ -d "$croot/etc" ]]; then
    echo "ERROR: Not a directory: $croot/etc" >&2
    exit 1
  fi

  nspawn_cfg="/etc/systemd/nspawn/${chost}.nspawn"
  if ! [[ -f "$nspawn_cfg" ]]; then
    echo "ERROR: Missing $nspawn_cfg" >&2
    exit 1
  fi
}

function reserve_id_range() {
  local chost="$1"

  local id_base=$(
    awk -F: -v chost="$chost" '$1 == chost {print $2; exit}' \
      /etc/subuid /etc/subgid)

  if [[ -z "$id_base" ]]; then
    local top_id=$( 
      awk -F: -v min="$MIN_ID" -v max="$MAX_ID" '
        $2 > top && $2 >= min && $2 <= max { top = $2 }
        END { print top }
      ' /etc/subuid /etc/subgid)

    id_base=$(( top_id + 65536 ))

    if ! awk -v b="$id_base" -F: '
        b >= $2 && b < ($2 + $3) {
            print "ERROR: id_base=" b " overlaps with \"" $0 "\" in " FILENAME
            exit 1
        }' /etc/subuid /etc/subgid; then
      exit 1
    fi

    echo "New id_base='$id_base'" >&2
    echo "$chost:$id_base:65536" >> /etc/subuid
    echo "$chost:$id_base:65536" >> /etc/subgid
  fi
  
  if [[ "$id_base" -lt 100000 ]]; then
    echo "ERROR: id_base=$id_base is too low (< 100,000)." >&2
    exit 1
  fi

  n=$(( id_base / 65536 ))
  id_base2=$(( n * 65536 ))
  if [[ "$id_base2" -ne "$id_base" ]]; then
    echo "ERROR: id_base ($id_base) is not a multiple of 65536." >&2
    exit 1
  fi
  
  echo "$id_base"
}

function assert_not_done() {
  local croot="$1"
  local id_base="$2"

  rootdir_uid=$(stat -c '%u' "$croot/.")
  rootdir_gid=$(stat -c '%g' "$croot/.")
  if [[ "$rootdir_uid" -eq "$id_base" ]] && \
     [[ "$rootdir_gid" -eq "$id_base" ]]; then
    echo "Already done (root dir UID/GID matches)."
    exit 0
  fi
}

function backup_ids() {
  local croot="$1"
  local tmpd="$2"

  pushd "$croot" > /dev/null
  getfacl -R . > "$tmpd/backup.getfacl"
  echo "Backup: $tmpd/backup.getfacl" >&2
  popd > /dev/null
}

function remap_ids() {
  local id_base="$1"
  local croot="$2"
  local tmpd="$3"

  pushd "$tmpd" > /dev/null
  find "$croot" -xdev -printf "%U\n" | sort -nu > all-uids
  find "$croot" -xdev -printf "%G\n" | sort -nu > all-gids

  for uid in $(cat all-uids); do
    if [[ "$uid" -ge "$MIN_MAP_ID" ]]; then
      continue
    fi

    new_uid=$(( id_base + uid ))
    find "$croot" -xdev -uid "$uid" -exec chown -h "$new_uid" {} +
  done

  for gid in $(cat all-gids); do
    if [[ "$gid" -ge "$MIN_MAP_ID" ]]; then
      continue
    fi

    new_gid=$(( id_base + gid ))
    find "$croot" -xdev -gid "$gid" -exec chgrp -h "$new_gid" {} +
  done

  popd > /dev/null
}

function main() {
  trap 'print_stack' ERR

  if [[ $# -ne 1 ]] || ! [[ -d "$1" ]]; then
    echo "Usage: $0 <container_root_directory>" >&2
    exit 1
  fi

  if ! [[ -d "$1" ]]; then
    fatal "Not a directory: $1"
  fi

  local croot=$(readlink -f "$1")
  local chost=$(basename "$croot")

  check_root_dir "$croot"

  local tmpd="$(mktemp -d "/tmp/remap-ids.XXXXXXXXXX")"

  if "$REMAP_CHECK" "$croot" &> "$tmpd/remap-check.out"; then
    echo "OK. Nothing to do. Remapping was already done."
    exit 0
  fi

  local id_base=$(reserve_id_range "$chost")

  #assert_not_done "$croot" "$id_base"

  backup_ids "$croot" "$tmpd"

  remap_ids "$id_base" "$croot" "$tmpd"

  echo "OK"
}

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

main "$@"
