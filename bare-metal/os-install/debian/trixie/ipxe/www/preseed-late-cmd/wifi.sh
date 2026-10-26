#!/bin/bash

set -eux

pcidev=$(lspci -D | egrep -i '(network|ethernet).*(wireless|802[.]11|wi.?fi|wlan)' | head -n1 | cut -f1 -d' ')
if [[ "$pcidev" ]]; then
  wifi_iface=$(ls /sys/bus/pci/devices/"$pcidev"/net | head -n1)
  if [[ "$wifi_iface" ]]; then
    sudo tee -a /etc/network/interfaces << __EOF__

auto $wifi_iface
iface $wifi_iface inet dhcp
    wpa-ssid ChimChim-G
    wpa-psk f00f00f00d
__EOF__
  fi
fi
