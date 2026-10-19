#!/bin/bash
#
# Remap UID/GID ownership, adding the specified number to each.
#
# For setting up a user namespace container filesystem with mapped IDs.
#

set -eu

MIN_ID=2000544
MAX_ID=8554044

function sanity_checks() {
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

  #nspawn_cfg="/etc/systemd/nspawn/${chost}.nspawn"
  #if ! [[ -f "$nspawn_cfg" ]]; then
  #  echo "ERROR: Missing $nspawn_cfg" >&2
  #  exit 1
  #fi
}

function reserve_id_range() {
  local chost="$1"

  local id_base=$(awk -F: -v host '$1 == host {print $2}')

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

    echo "DEBUG:" echo "$host:$id_base:65536" \>\> /etc/subuid
    echo "DEBUG:" echo "$host:$id_base:65536" \>\> /etc/subgid
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

function backup_ids() {
  local croot="$1"
  local tmpd="$2"

  cd "$croot"
  echo "DEBUG:" getfacl -R . \> "$tmpd/backup.getfacl"
  echo "Backup: $tmpd/backup.getfacl"
}

function remap_ids() {
  local id_base="$1"
  local croot="$2"
  local tmpd="$3"

  cd "$tmpd"
  find "$croot" -xdev -printf "%U\n" | sort -nu > all-uids
  find "$croot" -xdev -printf "%G\n" | sort -nu > all-gids

  for uid in $(cat all-uids); do
    new_uid=$(( id_base + uid ))
    echo find "$croot" -xdev -uid "$uid" -exec chown "$new_uid" {} +
  done

  for gid in $(cat all-gids); do
    new_gid=$(( id_base + gid ))
    echo find "$croot" -xdev -gid "$gid" -exec chgrp "$new_gid" {} +
  done
}

function main() {
  if [[ $# -ne 1 ]] || ! [[ -d "$1" ]]; then
    echo "Usage: $0 <container_root_directory>" >&2
    exit 1
  fi

  local croot=$1
  local chost=$(basename "$croot")

  sanity_checks "$croot"

  local id_base=$(reserve_id_range "$chost")

  local tmpd="$(mktemp -d "/tmp/remap-ids.XXXXXXXXXX")"

  backup_ids "$croot" "$tmpd"

  remap_ids "$id_base" "$croot" "$tmpd"

  echo SUCCESS
}

main "$@"
