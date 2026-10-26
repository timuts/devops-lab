#!/bin/bash

base_url="http://deb.debian.org/debian/dists/trixie/main/installer-amd64/current/images"

files=(
  netboot/debian-installer/amd64/linux
  netboot/debian-installer/amd64/initrd.gz
)

set -eu

wget -N -O .all-sha256-sums "$base_url/SHA256SUMS"

for f in "${files[@]}"; do
  wget -N "$base_url/$f"
done

: > .filtered-sha256-sums
for f in "${files[@]}"; do
  egrep " ([.]/)?$f" .all-sha256-sums \
    | sed -E 's@ ([.]/)?\S+/@ @' \
    >> .filtered-sha256-sums
done

echo
sha256sum -c .filtered-sha256-sums

rm .all-sha256-sums .filtered-sha256-sums
