# iPXE binaries

```
git clone https://github.com/ipxe/ipxe.git
cd ipxe/src

# Booting from PXE

make bin-x86_64-pcbios/ipxe.pxe
cp bin-x86_64-pcbios/ipxe.pxe /path/to/bare-metal/os-install/debian/trixie/ipxe/tftp/

# Booting from USB

make bin-x86_64-efi/ipxe.efi
sudo gdisk /dev/sdx
sudo mkfs.fat -F32 -n IPXEBOOT /dev/sdx1
sudo mkdir /mnt/fat
sudo mount /dev/sdx1 /mnt/fat
sudo mkdir -p /mnt/fat/EFI/BOOT
sudo cp bin-x86_64-efi/ipxe.efi /mnt/fat/EFI/BOOT/BOOTX64.EFI
```
