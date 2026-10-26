#!/bin/bash

set -eux

cat > /etc/systemd/system/console-poweroff.service << __EOF__
[Unit]
Description=Enable console blanking and poweroff
[Service]
Type=oneshot
Environment=TERM=linux
StandardOutput=tty
TTYPath=/dev/console
ExecStart=/usr/bin/setterm --blank 5 --powerdown 10
[Install]
WantedBy=multi-user.target
__EOF__
systemctl enable console-poweroff
