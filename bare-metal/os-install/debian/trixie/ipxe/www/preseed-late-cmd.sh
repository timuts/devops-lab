#!/bin/bash

d=preseed-late-cmd

exec &> "/root/$d.out"

cd "/root/$d" || exit

for f in *.sh; do
  out="${f%.sh}.out"
  if ./"$f" &> "$out"; then
    echo "SUCCESS: $f"
  else
    echo "FAILED:  $f: $d/$out"
  fi
done
