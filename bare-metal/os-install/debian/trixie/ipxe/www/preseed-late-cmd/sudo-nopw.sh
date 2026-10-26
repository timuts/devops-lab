#!/bin/bash

set -eux

sed -Ei 's/^(%sudo\s+.*)(\<ALL\s*)$/\1 NOPASSWD: \2/' /etc/sudoers
