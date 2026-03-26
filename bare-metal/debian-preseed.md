# Debian netboot & preseeding

## Objective

A fully automated, hands-off Debian install process. To the point where Puppet
can take over to finish and maintain the configuration.

## How it works

1.  PXE client runs from a ROM on the NIC.
1.  PXE client sends a "DHCP Discover" request.
1.  DHCP server responds with a "DHCP Offer" that includes the "next server"
    (TFTP server) and a boot filename.
1.  PXE client downloads the boot file from the TFTP server and runs it. This
    NBP (Network Bootstrap Program) could be Grub, iPXE, or others.
1.  NBP downloads the kernel and initrd and runs the kernel.
1.  Installer is started from the initrd.
1.  Installer uses parameters from the kernel command-line and the
    "preseed" file to avoid asking questions.
1.  Preseed file can include custom scripts to run early or late in the
    process.

## Infrastructure

### DHCP & TFTP

I used `dnsmasq` for this. It can serve DHCP, DNS, and TFTP out of one binary.

```bash
sudo apt install dnsmasq
```

My `/etc/dnsmasq.conf` on `seesaw`:

```ini
# Ignore DNS servers in /etc/resolv.conf
no-resolv
no-poll

interface=enp3s0

dhcp-authoritative
dhcp-range=192.168.125.100,192.168.125.199,18h

# No default route. Only because my house isn't wired for Ethernet, so I
# connect to the Internet via wifi (my default route). The four machines are
# connected to an isolated gigabit switch that will carry all inter-node
# traffic.
dhcp-option=3

# Set a fixed address and hostname for certain machines.
dhcp-host=40:61:86:XX:XX:XX,192.168.125.51,seesaw
dhcp-host=00:e2:4c:XX:XX:XX,192.168.125.52,slide
dhcp-host=84:69:93:XX:XX:XX,192.168.125.53,swings
dhcp-host=00:e0:4c:XX:XX:XX,192.168.125.54,zipline

# Set tag "ipxe" when option 77 == "iPXE" (as ipxe.efi does).
dhcp-userclass=set:ipxe,iPXE
# Default boot file
dhcp-boot=tag:!ipxe,ipxe.efi
# For when ipxe.efi runs and sends its own DHCP request.
dhcp-boot=tag:ipxe,http://192.168.125.51/boot/debian/trixie-ipxe/boot.ipxe

enable-tftp
tftp-root=/srv/boot/debian/trixie-ipxe/tftp

log-queries
```

Docs:

-   https://manpages.debian.org/trixie/dnsmasq-base/dnsmasq.8.en.html

### iPXE

I used [iPXE](https://ipxe.org/) instead of Grub to boot into the installer
because it can download files via HTTP (much faster than TFTP).

The file `boot.ipxe` referenced in the above dnsmasq config contains:

```bash
#!ipxe

set dir http://192.168.125.51/boot/debian/trixie-ipxe

kernel ${dir}/linux
initrd ${dir}/initrd.gz

boot linux initrd=initrd.gz auto=true priority=critical language=en country=US locale=en_US.UTF-8 keymap=us interface=auto netcfg/no_default_route=true netcfg/get_nameservers=192.168.125.51 mirror/http/proxy=http://192.168.125.51:3128 DEBCONF_DEBUG=5 preseed/url=${dir}/preseed.cfg
```

The `DEBCONF_DEBUG=5` is helpful to see which "question name" the installer got
stuck on. Look at syslog (press Alt+F4). You can set an answer for it in
preseed.cfg, or on the kernel command-line if it happens before the preseed
file is loaded.

I set `netcfg/no_default_route=true` because the machines are connected to an
isolated gigabit switch, so that segment doesn't have a default route.

Docs:

-   https://ipxe.org/docs


### HTTP

I used lighttpd on `seesaw` to serve the files `boot.ipxe`, `linux`,
`initrd.gz`, and `preseed.cfg` from `/var/www/html/boot/debian/trixie-ipxe`.

I downloaded `linux` and `initrd.gz` from:
http://deb.debian.org/debian/dists/trixie/main/installer-amd64/current/images/netboot/debian-installer/amd64/

```bash
sudo apt install lighttpd
```


### Missing Firmware

On one of the machines the installer was missing firmware for the NIC. There
aren't many options for making extra firmware files available before there is a
network connection. I chose to modify the initrd.

First, while in the installer, I pressed `Alt+F2` to get to a shell, then ran
`dmesg | less`, searched for `"failed to load"` and wrote down the filename
(including the directory name if present). `less /var/log/syslog` also mentions
the missing firmware file.

I used `apt-file` to search for the package that contains the file.

Make sure the `non-free-firmware` component is enabled in
`/etc/apt/sources.list`.

```bash
$ sudo apt install apt-file
$ sudo apt-file update
$ apt-file find rtl_nic/rtl8168d-1.fw
firmware-realtek: /usr/lib/firmware/rtl_nic/rtl8168d-1.fw
```

Download the package. No need to install it.

```bash
sudo apt install --download-only firmware-realtek

ls -l /var/cache/apt/archives/firmware-realtek*
```

If you don't yet have a machine running the target release from which to run
`apt-file`, you can hunt for the firmware file in:
https://cdimage.debian.org/cdimage/firmware/trixie/current/

```bash
$ mkdir /tmp/firmware
$ cd /tmp/firmware
$ wget https://cdimage.debian.org/cdimage/firmware/trixie/current/firmware.tar.gz
$ tar zxf firmware.tar.gz
$ grep rtl_nic/rtl8168d-1.fw Contents-firmware
/usr/lib/firmware/rtl_nic/rtl8168d-1.fw                 firmware-realtek_20250410-2_all.deb non-free-firmware
```

Extract the contents of the `*.deb` file. Substitute the path
`/tmp/firmware/firmware-realtek_20250410-2_all.deb` if you got it from
`firmware.tar.gz`.

```bash
$ mkdir /tmp/firmware-realtek_20250410-2_all
$ cd /tmp/firmware-realtek_20250410-2_all
$ dpkg-deb -X /var/cache/apt/archives/firmware-realtek_20250410-2_all.deb .
$ find | grep rtl_nic/rtl8168d-1.fw
./usr/lib/firmware/rtl_nic/rtl8168d-1.fw
```

Unpack the initrd cpio file, add the firmware file(s) at the exact same path as
in the `*.deb` file, and create a new `initrd.gz`. `fakeroot` is used to
preserve root ownership and special files in `/dev`.

```bash
cp -a initrd.gz initrd.gz.bak1

fakeroot
mkdir initrd
cd initrd
zcat ../initrd.gz | cpio -i

mkdir ./usr/lib/firmware/rtl_nic
cp -a /tmp/firmware-realtek_20250410-2_all/usr/lib/firmware/rtl_nic/rtl8168d-1.fw ./usr/lib/firmware/rtl_nic/

find | cpio -H newc -o | gzip -9 > ../initrd.gz

# quit fakeroot
exit
```

To verify that the file was inserted successfully without any other change,
diff the listings of the contents:

```bash
$ zcat initrd.gz.bak1 | cpio -t | sort > initrd.list.old
$ zcat initrd.gz | cpio -t | sort > initrd.list.new
$ diff -u initrd.list.{old,new}
```

```diff
--- initrd.list.old     2026-03-26 13:44:49.197226274 -0700
+++ initrd.list.new     2026-03-26 13:49:05.964179667 -0700
@@ -1075,6 +1075,8 @@
 usr/lib/firmware
 usr/lib/firmware/regulatory.db
 usr/lib/firmware/regulatory.db.p7s
+usr/lib/firmware/rtl_nic
+usr/lib/firmware/rtl_nic/rtl8168d-1.fw
 usr/lib/libasound.so.2
 usr/lib/libasound.so.2.0.0
 usr/lib/libcrypto.so.3
```


### Caching Proxy

I'm using a Squid proxy as a cache running on `seesaw` to speed up subsequent
installs.

```bash
sudo apt install squid
```

My `/etc/squid/squid.conf` on `seesaw`:

```
http_port 3128

acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 1025-65535

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager

acl localnet src 192.168.0.0/16
http_access allow localnet
http_access allow localhost
http_access deny all

cache_dir aufs /var/spool/squid 16384 16 256
maximum_object_size 150 MB

coredump_dir /var/spool/squid

# Hold on to package files longer. They're versioned and existing versions
# won't be updated.
# min cache time = 129600  #  90 days
# max cache time = 259200  # 180 days
refresh_pattern .*\.(deb|udeb)$ 129600 90% 259200 override-expire override-lastmod

# Make sure the Debian preseed files always have the latest updates.
refresh_pattern /preseed\.cfg      0 0% 0
refresh_pattern /preseed-late-cmd  0 0% 0

# Stock patterns.
refresh_pattern ^ftp:              1440  20%  10080
refresh_pattern -i (/cgi-bin/|\?)     0   0%      0
refresh_pattern .                     0  20%   4320

# Logs are managed by logrotate on Debian
logfile_rotate 0
```

Docs:

-   https://www.squid-cache.org/Versions/v5/cfgman/

## Preseed

My preseed file:

```
#_preseed_V1

d-i debian-installer/locale string en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us
d-i netcfg/choose_interface select auto

# The preseed files and the proxy server are on the local network, so we don't
# need a default route for now.
d-i netcfg/no_default_route boolean true

d-i netcfg/get_hostname string unassigned-hostname
d-i netcfg/get_domain string unassigned-domain

d-i netcfg/wireless_wep string
d-i netcfg/wireless_essid string XXXXXXXXXX
d-i netcfg/wireless_security_type select wpa
d-i netcfg/wireless_wpa string XXXXXXXXXX

d-i hw-detect/load_firmware boolean true

d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string http://192.168.125.51:3128

# Must use sudo for root access.
d-i passwd/root-login boolean false

d-i passwd/user-fullname string System Admin
d-i passwd/username string sysadm
d-i passwd/user-password-crypted password $y$j9T$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

d-i clock-setup/utc boolean true
d-i time/zone string America/Los_Angeles
d-i clock-setup/ntp boolean true

d-i partman-auto/init_automatically_partition select biggest_free
d-i partman-auto/method string regular
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto/choose_recipe select atomic
d-i partman-auto/expert_recipe string                         \
      boot-root ::                                            \
              768 10001 1024 free                             \
                      $primary{ }                             \
                      $iflabel{ msdos gpt }                   \
                      $reusemethod{ }                         \
                      method{ efi }                           \
                      format{ }                               \
              .                                               \
              500 10000 1000000000 ext4                       \
                      method{ format } format{ }              \
                      use_filesystem{ } filesystem{ ext4 }    \
                      mountpoint{ / }                         \
              .                                               \
              2048 512 2048 linux-swap                        \
                      method{ swap } format{ }                \
              .
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-partitioning/choose_label select gpt
d-i partman-md/confirm boolean true
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

d-i apt-setup/cdrom/set-first boolean false
d-i apt-setup/non-free-firmware boolean true
d-i apt-setup/non-free boolean true

tasksel tasksel/first multiselect standard
d-i pkgsel/include string openssh-server acpi arping bc bind9-dnsutils bind9-host bridge-utils curl dmidecode ethtool gnupg iproute2 iputils-ping iputils-tracepath iw ncal netcat-openbsd net-tools pinentry-tty pinentry-curses pv rsync screen sipcalc strace sysstat tcpdump traceroute vim vim-scripts wget wireless-tools wpasupplicant
d-i pkgsel/upgrade select safe-upgrade

d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string default

d-i finish-install/keep-consoles boolean true
d-i finish-install/reboot_in_progress note

# The tiny scripts in this tarball handle things like installing SSH keys,
# configuring sudo, installing missing firmware, and turning on console
# blanking & poweroff.
d-i preseed/late_command string \
  in-target curl -so /root/preseed-late-cmd.tgz http://192.168.125.51/boot/debian/trixie-ipxe/preseed-late-cmd.tgz; \
  in-target tar -C /root -zxf /root/preseed-late-cmd.tgz; \
  in-target /root/preseed-late-cmd.sh
```

TODO: Link to the contents of `preseed-late-cmd.tgz`.

Docs:

-   https://www.debian.org/releases/trixie/example-preseed.txt
-   https://www.debian.org/releases/trixie/amd64/apb.en.html
