#!/bin/bash

set -eux

apt install -y apt-file

apt-file update

fw_pkgs=$(
  for fw in $(dmesg | sed -En 's/.*firmware: failed to load (\S+).*/\1/p' | sort -u); do
    apt-file find "$fw" | sed -En 's@^(\S+): /\S+$@\1@p';
  done | sort -u)

if [[ "$fw_pkgs" ]]; then
  apt install -y $fw_pkgs
fi
