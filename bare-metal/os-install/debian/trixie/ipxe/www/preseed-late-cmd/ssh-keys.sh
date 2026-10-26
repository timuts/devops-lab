#!/bin/bash

set -eux

mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN8hJn/SgGlqKnUfHFYYv4tibON77irfTPmKWD4HJSUc tim@poppy" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

cp -a /root/.ssh /home/sysadm/
chown -hR sysadm: /home/sysadm/.ssh
